//
//  ViewController.swift
//  AudioUnitRenderIssueExampleProject
//
//  Created by Sasha Ivanov on 2016-09-05.
//  Copyright © 2016 madebysasha.com All rights reserved.
//

/********************************************************************************************************************************************************/
/* Example Project for http://stackoverflow.com/questions/39310065/audiounitrender-and-extaudiofilewrite-error-50-in-swift-trying-to-convert-midi       */
/* To test the converted audio file, check the Console to receive a path of the file. Then, use the Finder to go to that folder.                        */
/********************************************************************************************************************************************************/

import UIKit
import MIKMIDI

class ViewController: UIViewController {

    @IBAction func PressPlayButton(sender: AnyObject) {
        
        playMIDI()
        
    }
    
    
    @IBAction func PressConvertButton(sender: AnyObject) {
        
        convertMIDItoAudioFile()
    }
    
    // The Sequencer for Playing back MIDI
    var sequencer = MIKMIDISequencer()
    
    // The Snynthesizer's Graph and Audio Unit
    var synthGraph = AUGraph()
    var synthAudioUnit = AudioUnit()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMIDI()
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // Loads MIDI file into a MIKMIDI Sequencer
    func setupMIDI(){
        
        // Create URL to Load MIDI
        let url = NSBundle.mainBundle().URLForResource("test", withExtension: "mid")
        
        do{
            
            // Load MIDI File into MIKMIDI Sequence & add to sequencer
            let sequence = try MIKMIDISequence(fileAtURL: url!)
            sequencer = MIKMIDISequencer(sequence: sequence)
            
            // Load Soundfont and apply it to each track in the sequence
            sequencer.createSynthsIfNeeded = true
            
            for t in sequence.tracks{
                let synth = sequencer.builtinSynthesizerForTrack(t)
                let synthURL = NSBundle.mainBundle().URLForResource("Stereo Piano", withExtension: ".sf2")
                try synth!.loadSoundfontFromFileAtURL(synthURL!)
                
                // Get the Synthesizer's Graph and Audio Unit for Converting
                synthGraph = (synth?.graph)!
                synthAudioUnit = (synth?.instrumentUnit)!
            }
            
            // Set tempo and other Sequence Presets
            sequencer.tempo = 120
            
        }
            
        catch{
            print("Could not setup MIDI")
        }

    }
    
    
    // Plays Back MIDI File
    func playMIDI(){
        sequencer.startPlayback()
    }
    
    
    
    // An Attempt to Convert MIDI to a .m4a Audio File, Currently produces Noise.
    func convertMIDItoAudioFile(){
        var generalOutputNode = AUNode()
        var generalIOAudioUnit = AudioUnit()
        var genericOutputDesc = AudioComponentDescription()
        genericOutputDesc.componentType = kAudioUnitType_Output
        genericOutputDesc.componentSubType = kAudioUnitSubType_GenericOutput
        genericOutputDesc.componentFlags = 0
        genericOutputDesc.componentFlagsMask = 0
        genericOutputDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        
        var nodeCount:UInt32 = 0
        AUGraphGetNodeCount(synthGraph, &nodeCount)
        
        // First we need to remove the IO Node from the graph.
        
        // Stop the Graph, Close it.
        var result = AUGraphStop(synthGraph)
        result = AUGraphClose(synthGraph)
        
        // Goodbye IONode (at Index 0?)
        var ioNode = AUNode()
        result = AUGraphGetIndNode(synthGraph, 0, &ioNode)
        result = AUGraphRemoveNode(synthGraph, ioNode)
        
        // Update the Graph
        var ouputUpdated:DarwinBoolean = false
        result = AUGraphUpdate(synthGraph, &ouputUpdated)
        
        result = AUGraphGetNodeCount(synthGraph, &nodeCount)
        
        // Add the Generic Node to the synthesizer's Graph
        var runres:DarwinBoolean = false
        AUGraphIsRunning(synthGraph, &runres)
        
        result = AUGraphAddNode(synthGraph, &genericOutputDesc, &generalOutputNode)
        
        // Re-Open the Graph
        result = AUGraphOpen(synthGraph)
        result = AUGraphInitialize(synthGraph)
        
        // Get the number of nodes in the synth's Graph
        nodeCount = 0
        result = AUGraphGetNodeCount(synthGraph, &nodeCount)
        
        // Get the index of the last node
        var synthNode:AUNode = AUNode()
        result = AUGraphGetIndNode(synthGraph, nodeCount-1, &synthNode)
        
        // Reference the AudioUnit Objects
        result = AUGraphNodeInfo(synthGraph, synthNode, nil, &synthAudioUnit)
        result = AUGraphNodeInfo(synthGraph, generalOutputNode, &genericOutputDesc, &generalIOAudioUnit)
        
        // Connect Node 0 to the New Node
        
        result = AUGraphGetNodeCount(synthGraph, &nodeCount)
        result = AUGraphGetIndNode(synthGraph, nodeCount-1, &synthNode)
        result = AUGraphConnectNodeInput(synthGraph, synthNode, 0, generalOutputNode, 0)
        
        // Update the Graph
        result = AUGraphUpdate(synthGraph, &ouputUpdated)
        result = AUGraphGetNodeCount(synthGraph, &nodeCount)
        
        // Audioplayback section should already be handled by MIKMIDI
        
        // Set ASBD for the File with correct format
        var clientFormat = AudioStreamBasicDescription()
        var clientSize:UInt32 = UInt32(sizeofValue(clientFormat))
        memset(&clientFormat, 0, sizeofValue(clientFormat))
        
        // Get the audio data from the Output Unit
        result = AudioUnitGetProperty(generalIOAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &clientFormat, &clientSize)
        
        // Prepare File to Save to
        var destinationFormat = AudioStreamBasicDescription()
        memset(&destinationFormat, 0, sizeofValue(destinationFormat))
        destinationFormat.mChannelsPerFrame = 1
        destinationFormat.mFormatID = kAudioFormatMPEG4AAC
        destinationFormat.mSampleRate = clientFormat.mSampleRate
        var destSize:UInt32 = UInt32(sizeofValue(destinationFormat))
        result = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &destSize, &destinationFormat)
        
        // Create a File to save to in the Documents Directory
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        let fileName = NSUUID().UUIDString
        let outputPath = documentsPath.stringByAppendingPathComponent("\(fileName)_MIDICONVERT.m4a")
        let outputURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, outputPath, .CFURLPOSIXPathStyle, false)
        print(outputPath)
        
        // Specify the codec, i.e. .m4a format
        var extAudioFile = ExtAudioFileRef()
        result = ExtAudioFileCreateWithURL(outputURL, kAudioFileM4AType, &destinationFormat, nil, AudioFileFlags.EraseFile.rawValue, &extAudioFile)
        
        // Set the Audio Data Format of the Synth Unit
        result = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, UInt32(sizeofValue(clientFormat)), &clientFormat)
        
        // Specify the synth codec
        var synthCodec = kAppleHardwareAudioCodecManufacturer
        result = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_CodecManufacturer, UInt32(sizeofValue(synthCodec)), &synthCodec)
        
        // Start Playing it Back
        var startTime:MusicTimeStamp = -1.0 // on next cycle
        sequencer.startPlaybackAtTimeStamp(startTime)
        
        // Write fist bit to file
        result = ExtAudioFileWriteAsync(extAudioFile, 0, nil)
        
        // Feed the Output Node buffer into the File
        let busNum:UInt32 = 0
        var buffFrames = 1024
        let channels:UInt32 = 1 // try 1 channel first?
        
        var flags = AudioUnitRenderActionFlags.OfflineUnitRenderAction_Preflight
        
        var inTimeStamp = AudioTimeStamp()
        memset(&inTimeStamp, 0, sizeofValue(AudioTimeStamp))
        inTimeStamp.mFlags = .SampleTimeValid
        inTimeStamp.mSampleTime = 0
        
        
        // RIGHT NOW WE DO NOT KNOW THE TOTAL NUMBER OF FRAMES TO BE RENDERED AS OUTPUT : TODO
        var totalFrames = Int(sequencer.sequence.length * 1024)
        
        while(totalFrames > 0){
            
            // Keep Track of how many frames are left
            if(totalFrames < buffFrames){
                buffFrames = totalFrames
            }
                
            else{
                totalFrames -= buffFrames
            }
            
            var bufferList = AudioBufferList.allocate(maximumBuffers: 1)
            
            for i in 0...bufferList.count-1{
                
                var buffer = AudioBuffer()
                buffer.mNumberChannels = 1
                buffer.mDataByteSize = UInt32(buffFrames*sizeofValue(AudioUnitSampleType))
                buffer.mData = calloc(buffFrames, sizeofValue(AudioUnitSampleType))
                
                bufferList[i] = buffer
            }
            
            
            result = AudioUnitRender(generalIOAudioUnit, &flags, &inTimeStamp, busNum, UInt32(buffFrames), bufferList.unsafeMutablePointer) // Returns -50
            inTimeStamp.mSampleTime += Float64(buffFrames)
            
            result = ExtAudioFileWriteAsync(extAudioFile, UInt32(buffFrames), bufferList.unsafeMutablePointer)
        }
    
        // Clean up Audio File
        result = ExtAudioFileDispose(extAudioFile)
    }
}


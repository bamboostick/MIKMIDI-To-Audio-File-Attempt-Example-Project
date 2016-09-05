# MIKMIDI-To-Audio-File-Attempt-Example-Project
An attempt to convert MIDI to an M4A file using MIKMIDI. Currently produces a noise audio file. 
More details at: 
http://stackoverflow.com/questions/39310065/audiounitrender-and-extaudiofilewrite-error-50-in-swift-trying-to-convert-midi

SETUP
1. Run cocoapods "pod install" in the main project directory.

USAGE
Run the app and tap the Play MIDI button to ensure MIKMIDI is added to the project correctly. You should be able to hear
the midi file being played back. 

Next, tap the Convert Midi button to try and convert the midi to an .m4a audio file. In the Xcode console, you will see the
path of the audio file on your computer. Use the Finder to locate the file by using the Go To Folder option in the Go menu
at the top of the screen. Currently, the audio file should simply playback a second of random noise. Instead of noise, I
would like the audio file to contain the same sound that is played back with the Play MIDI button. If anyone has any advice
on how to accomplish this please let me know at the stackoverflow url at the top of the page.

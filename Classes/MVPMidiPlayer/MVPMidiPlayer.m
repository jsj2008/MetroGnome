//
//  MVPMidiPlayer.m
//  FirstGame
//
//  Created by Ben Smiley-Andrews on 15/03/2012.
//  Copyright 2012 Deluge. All rights reserved.
//

#import "MVPMidiPlayer.h"


#define kLowNote  48
#define kHighNote 72
#define kMidNote  60

@interface MVPMidiPlayer (Private)
-(BOOL)createAUGraph;
-(void)configureAndStartAudioProcessingGraph:(AUGraph)graph;
@end

@implementation MVPMidiPlayer

@synthesize processingGraph     = _processingGraph;
@synthesize samplerUnit         = _samplerUnit;
@synthesize ioUnit              = _ioUnit;
@synthesize player              = _player;

/*******************************************************************************/

// Releases MusicSequence, MusicPlayer, and self
-(void)dealloc {
    // Dispose of sequence
    MusicSequence s;
    NewMusicSequence(&s);
    MusicPlayerGetSequence(self.player, &s);
    DisposeMusicSequence(s);
    
    // Dispose of player
    MusicPlayerStop(self.player);
    DisposeMusicPlayer(self.player);
    [super dealloc];
}

// Generic init method
-(id)init {
	if (self = [super init]) {

	}
	return self;
}

/*******************************************************************************/
/* Creates AUGraph with two AUNodes:
 Sampler: This is a unit converts MIDI to music sounds defined 
    in a Sound Font or AUPreset and is available on iOS 5
 RemoteIO: This unit allows us to output sounds to iPhone speakers */
-(BOOL)createAUGraph {
    
    // Each core audio call returns an OSStatus. This means that we
    // Can see if there have been any errors in the setup
	OSStatus result = noErr;
    
    // Create 2 audio units, one sampler and one IO
	AUNode samplerNode, ioNode;
    
    // Specify the common portion of an audio unit's identify, used for both audio units
    // in the graph.
    // Setup the manufacturer - in this case Apple
	AudioComponentDescription cd = {};
	cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    
    // Instantiate an audio processing graph
	result = NewAUGraph (&_processingGraph);
    NSCAssert (result == noErr, @"Unable to create an AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	//Specify the Sampler unit, to be used as the first node of the graph
	cd.componentType = kAudioUnitType_MusicDevice; // type - music device
	cd.componentSubType = kAudioUnitSubType_Sampler; // sub type - sampler to convert our MIDI
	
    // Add the Sampler unit node to the graph
	result = AUGraphAddNode (self.processingGraph, &cd, &samplerNode);
    NSCAssert (result == noErr, @"Unable to add the Sampler unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Specify the Output unit, to be used as the second and final node of the graph	
	cd.componentType = kAudioUnitType_Output;  // Output
	cd.componentSubType = kAudioUnitSubType_RemoteIO;  // Output to speakers
    
    // Add the Output unit node to the graph
	result = AUGraphAddNode (self.processingGraph, &cd, &ioNode);
    NSCAssert (result == noErr, @"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Open the graph
	result = AUGraphOpen (self.processingGraph);
    NSCAssert (result == noErr, @"Unable to open the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Connect the Sampler unit to the output unit
	result = AUGraphConnectNodeInput (self.processingGraph, samplerNode, 0, ioNode, 0);
    NSCAssert (result == noErr, @"Unable to interconnect the nodes in the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Obtain a reference to the Sampler unit from its node
	result = AUGraphNodeInfo (self.processingGraph, samplerNode, 0, &_samplerUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
	// Obtain a reference to the I/O unit from its node
	result = AUGraphNodeInfo (self.processingGraph, ioNode, 0, &_ioUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    return YES;
}

/*******************************************************************************/

// Starting with instantiated audio processing graph, configure its 
// audio units, initialize it, and start it.
- (void) configureAndStartAudioProcessingGraph: (AUGraph) graph {
    
    OSStatus result = noErr;
    if (graph) {
        
        // Initialize the audio processing graph.
        result = AUGraphInitialize (graph);
        NSAssert (result == noErr, @"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Start the graph
        result = AUGraphStart (graph);
        NSAssert (result == noErr, @"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Print out the graph to the console
        //CAShow (graph); 
    }
}

/*******************************************************************************/

void MyMIDINotifyProc (const MIDINotification  *message, void *refCon) {
    printf("MIDI Notify, messageId=%d,", message->messageID);
}

static void MyMIDIReadProc(const MIDIPacketList *pktlist,
                           void *refCon,
                           void *connRefCon) {

    
    AudioUnit *player = (AudioUnit*) refCon;
    
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
    for (int i=0; i < pktlist->numPackets; i++) {
        Byte midiStatus = packet->data[0];
        Byte midiCommand = midiStatus >> 4;
        
        
        if (midiCommand == 0x09) {
            Byte note = packet->data[1] & 0x7F;
            Byte velocity = packet->data[2] & 0x7F; 
            
            int noteNumber = ((int) note) % 12;
            NSString *noteType;
            switch (noteNumber) {
                case 0:
                    noteType = @"C";
                    break;
                case 1:
                    noteType = @"C#/Db";
                    break;
                case 2:
                    noteType = @"D";
                    break;
                case 3:
                    noteType = @"D#/Eb";
                    break;
                case 4:
                    noteType = @"E";
                    break;
                case 5:
                    noteType = @"F";
                    break;
                case 6:
                    noteType = @"F#/Gb";
                    break;
                case 7:
                    noteType = @"G";
                    break;
                case 8:
                    noteType = @"G#/Ab";
                    break;
                case 9:
                    noteType = @"A";
                    break;
                case 10:
                    noteType = @"A#/Bb";
                    break;
                case 11:
                    noteType = @"B";
                    break;
                default:
                    break;
            }
            NSLog([noteType stringByAppendingFormat:[NSString stringWithFormat:@": %i", noteNumber]]);
           
            
            OSStatus result = noErr;
            result = MusicDeviceMIDIEvent (player, midiStatus, note, velocity, 0);
        }
        packet = MIDIPacketNext(packet);
    }
}

/*******************************************************************************/

// this method assumes the class has a member called mySamplerUnit
// which is an instance of an AUSampler
-(OSStatus) loadFromDLSOrSoundFont: (NSURL *)bankURL withPatch: (int)presetNumber {

    OSStatus result = noErr;

    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;

    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(self.samplerUnit,
                              kAUSamplerProperty_LoadPresetFromBank,
                              kAudioUnitScope_Global,
                              0,
                              &bpdata,
                              sizeof(bpdata));

    // check for errors
    NSCAssert (result == noErr,
           @"Unable to set the preset property on the Sampler. Error code:%d '%.4s'",
           (int) result,
           (const char *)&result);

    return result;
}

/*******************************************************************************/
#pragma mark -
#pragma mark Public methods
/*******************************************************************************/
/* Init MVPMidiPlayer with a midi file located at midiFileURL */
-(id)initWithMidiFileURL:(NSURL *)midiFileURL {
    if (self = [super init]) {
        OSStatus result = noErr;
        
        [self createAUGraph];
        [self configureAndStartAudioProcessingGraph: self.processingGraph];
        
        // Create a client
        MIDIClientRef virtualMidi;
        result = MIDIClientCreate(CFSTR("Virtual Client"),
                                  MyMIDINotifyProc,
                                  NULL,
                                  &virtualMidi);
        
        NSAssert( result == noErr, @"MIDIClientCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Create an endpoint
        MIDIEndpointRef virtualEndpoint;
        result = MIDIDestinationCreate(virtualMidi, @"Virtual Destination", MyMIDIReadProc, self.samplerUnit, &virtualEndpoint);
        
        NSAssert( result == noErr, @"MIDIDestinationCreate failed. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        
        
        // Create a new music sequence
        MusicSequence sequence;
        // Initialise the music sequence
        NewMusicSequence(&sequence);
        MusicSequenceFileLoad(sequence, (__bridge CFURLRef) midiFileURL, 0, 0);
        
        // Create a new music player
        MusicPlayer  p;
        // Initialise the music player
        NewMusicPlayer(&p);
        // Set as property player
        self.player = p;
        
        // Set the endpoint of the sequence to be our virtual endpoint
        MusicSequenceSetMIDIEndpoint(sequence, virtualEndpoint);
        
        // Load the sound font from file, use preset 1 for piano
        NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:@"ChoriumRevA" ofType:@"SF2"]];
        
        // Initialise the sound font
        [self loadFromDLSOrSoundFont: (NSURL *)presetURL withPatch: (int)1];
        
        // Load the sequence into the music player
        MusicPlayerSetSequence(self.player, sequence);
        // Called to do some MusicPlayer setup. This just 
        // reduces latency when MusicPlayerStart is called
        MusicPlayerPreroll(self.player);
        }
    return self;
}


/******************************************************************************/
-(void)play {
    MusicPlayerStart(self.player);
}

/* Returns true if instance is currently playing */
-(bool)isPlaying {
    Boolean *b;
    MusicPlayerIsPlaying(self.player, b);
    return (bool) b;
}

/* Stops the player, returns timestamp of current position */
-(MusicTimeStamp)pause {
    MusicTimeStamp time = 0;
    if ([self isPlaying]) {
        MusicPlayerStop(self.player);
        MusicPlayerGetTime (self.player, &time);
    }
    else NSLog(@"MVPMidiPlayer paused while not playing");
    return time;
}

/* Sets time position of sequence held by self.player */
-(void)setTime:(MusicTimeStamp)timeStamp {
    MusicPlayerSetTime(self.player, timeStamp);
}

/* Stops the player, sets timestamp to beginning of sequence */
-(void)stop {
    [self pause];
    [self setTime:0];
}

/* Returns sequence being held by self.player 
 Sequence is a defined in AudioToolbox, it is what is played by MusicPlayer */
-(MusicSequence)getSequence {
    MusicSequence s;
    NewMusicSequence(&s);
    MusicPlayerGetSequence(self.player, &s);
    DisposeMusicSequence(s);
    MusicPlayerGetSequence(self.player, &s);   
    return s;
}

/* Sets function for midi call back */ 
-(void)setMidiCallback {
    //incomplete
}


#pragma mark -
#pragma mark Testing code
/******************************************************************************/
/* Test the MVPMidiPlayer class and all methods */
+(void)test {
    NSLog(@"Entered MVPMidiPlayer testing function");
    
    /* testPlayer1 ************************************************************/
    MVPMidiPlayer *testPlayer1 = [[MVPMidiPlayer alloc]init];
    [testPlayer1 dealloc];
    
    
    /* testPlayer2 ************************************************************/
    NSString *midiFilePath = [[NSBundle mainBundle]
                              pathForResource:@"simpletest"
                              ofType:@"mid"];
    NSURL * midiFileURL = [NSURL fileURLWithPath:midiFilePath];
    MVPMidiPlayer *testPlayer2 = [[MVPMidiPlayer alloc]initWithMidiFileURL:midiFileURL];
    [testPlayer2 play];
    
    // Test isPlaying
    bool b = [testPlayer2 isPlaying];
    if (!b) {
        NSLog(@"isPlaying method failed");
    }
    
    // Test getSequence
    MusicSequence s = [testPlayer2 getSequence];
    if (!s) {
        NSLog(@"getSequence method failed. Returned null sequence");
    }
    
    // Test pause
    usleep (2 * 1000 * 1000);
    MusicTimeStamp stamp = [testPlayer2 pause];
    NSLog(@"%f", stamp);
    usleep (2 * 1000 * 1000);
    [testPlayer2 play];
    
    
    // Get length of track so that we know how long to kill time for
    MusicTrack t;
    MusicTimeStamp len;
    UInt32 sz = sizeof(MusicTimeStamp);
    MusicSequenceGetIndTrack(s, 1, &t);
    MusicTrackGetProperty(t, kSequenceTrackProperty_TrackLength, &len, &sz);
    
    while (1) { // kill time until the music is over
        usleep (2 * 1000 * 1000); // suspend thread execution, measured in microseconds
        MusicTimeStamp now = 0;
        MusicPlayerGetTime (testPlayer2.player, &now);
        if (now >= len)
            break;
    }

    [testPlayer2 dealloc];
    
    
    /* testPlayer3 ************************************************************/
    MVPMidiPlayer *testPlayer3 = [[MVPMidiPlayer alloc]initWithMidiFileURL:midiFileURL];
    
    // Test setTime. stamp is from testPlayer2. 
    [testPlayer3 setTime:0];
    [testPlayer3 play];
    
    [testPlayer3 dealloc];
    
    
    NSLog(@"Exited MVPMidiPlayer testing function");
}


@end


#include "AudioPlayer.h"
#include "MidiHandler.hpp"
#include <AVFoundation/AVFoundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include "SequencerAudioUnit.h"
#include "DrumSequencerAudioUnit.h"
#include "MidiObjects.h"

@implementation Chord2Event

@end

@implementation Rhythm2Event

@end

// MARK: -

static void MidiCallback(void * ref, int note, int velocity) {
    AudioPlayer * player = (__bridge AudioPlayer *)ref;
    [player handleMidi:note velocity: velocity];
}

@interface AudioPlayer () {
    bool playing;
    bool repeating;
    AVAudioEngine * audioEngine;
    AVAudioUnitSampler * keyboardSampler;
    AVAudioUnit * keyboardSequencer;
    AVAudioUnitSampler * drumSampler;
    AVAudioUnit * drumSequencer;
    MidiHandler midiHandler;
}

@end

@implementation AudioPlayer

- (instancetype)init {
    if (self = [super init]) {
        audioEngine = [AVAudioEngine new];
        
        keyboardSampler = [AVAudioUnitSampler new];
        [audioEngine attachNode:keyboardSampler];
        [audioEngine connect:keyboardSampler to:audioEngine.mainMixerNode format:nil];
        
        drumSampler = [AVAudioUnitSampler new];
        [audioEngine attachNode:drumSampler];
        [audioEngine connect:drumSampler to:audioEngine.mainMixerNode format:nil];
        
        midiHandler = MidiHandler();
        midiHandler.startSession();
        midiHandler.setCallback(MidiCallback, (__bridge void *)self);
        
        [self instantiateSequencer];
        [self instantiateDrumSequencer];
        
        NSError * error;
        [audioEngine startAndReturnError:&error];
    }
    return self;
}

- (void)instantiateSequencer {

    UInt32 myUnitType = kAudioUnitType_MIDIProcessor;
    OSType mySubType = 1;

    AudioComponentDescription compDesc;
    compDesc.componentType = myUnitType;
    compDesc.componentSubType = mySubType;
    compDesc.componentManufacturer = 0x665f6f20; // 'foo '
    compDesc.componentFlags = kAudioComponentFlag_SandboxSafe;
    compDesc.componentFlagsMask = 0;

    [AUAudioUnit registerSubclass:[SequencerAudioUnit class]
                            asComponentDescription:compDesc
                                          name:@"Sequencer"
                                       version:1];

    [AVAudioUnit instantiateWithComponentDescription:compDesc
                                             options:0
                                   completionHandler:^(AVAudioUnit * _Nullable audioUnit, NSError * _Nullable error) {
        if (!audioUnit) return;
    
        [self->audioEngine attachNode:audioUnit];
        self->keyboardSequencer = audioUnit;
        
        [self->audioEngine connectMIDI:audioUnit to:self->keyboardSampler format:nil eventListBlock:nil];
    }];
}

- (void)instantiateDrumSequencer {

    UInt32 myUnitType = kAudioUnitType_MIDIProcessor;
    OSType mySubType = 1;

    AudioComponentDescription compDesc;
    compDesc.componentType = myUnitType;
    compDesc.componentSubType = mySubType;
    compDesc.componentManufacturer = 0x666f6f20; // 'foo '
    compDesc.componentFlags = kAudioComponentFlag_SandboxSafe;
    compDesc.componentFlagsMask = 0;

    [AUAudioUnit registerSubclass:[DrumSequencerAudioUnit class]
                            asComponentDescription:compDesc
                                          name:@"DrumSequencer"
                                       version:1];

    [AVAudioUnit instantiateWithComponentDescription:compDesc
                                             options:0
                                   completionHandler:^(AVAudioUnit * _Nullable audioUnit, NSError * _Nullable error) {
        if (!audioUnit) return;
        
        [self->audioEngine attachNode:audioUnit];
        self->drumSequencer = audioUnit;
        
        [self->audioEngine connectMIDI:audioUnit to:self->drumSampler format:nil eventListBlock:nil];
    }];
}

- (void)dealloc
{
}

// MARK: -

- (void)handleMidi:(int)note velocity:(int)velocity
{
    if (velocity > 0) {
        [keyboardSampler startNote:note withVelocity:velocity onChannel:1];
    } else {
        [keyboardSampler stopNote:note onChannel:0];
    }
}

// MARK: -

- (void)loadSoundfont:(NSString *)path {
    NSFileManager * fileManager = [NSFileManager new];
    if (![fileManager fileExistsAtPath:path]) return;
    
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError * error;
    [keyboardSampler loadSoundBankInstrumentAtURL:url program:0 bankMSB:0x79 bankLSB:0x00 error:&error];
}

- (void)loadDrumSoundfont:(NSString *)path {
    NSFileManager * fileManager = [NSFileManager new];
    if (![fileManager fileExistsAtPath:path]) return;
    
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError * error;
    [drumSampler loadSoundBankInstrumentAtURL:url program:0 bankMSB:0x78 bankLSB:0x00 error:&error];
}

- (void)playNote:(uint8_t)note velocity:(uint8_t)velocity {
    if (repeating) {
        [(SequencerAudioUnit *)keyboardSequencer.AUAudioUnit pressNote:note];
    } else {
        [keyboardSampler startNote:note withVelocity:velocity onChannel:1];
    }
}

- (void)stopNote:(uint8_t)note {
    if (repeating) {
        [(SequencerAudioUnit *)keyboardSequencer.AUAudioUnit releaseNote:note];
    } else {
        [keyboardSampler stopNote:note onChannel:1];
    }
}

- (void)startSequencer {
    playing = true;
    if (drumSequencer != nullptr) {
        [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit setPlaying:true];
    }
    if (keyboardSequencer != nullptr) {
        [(SequencerAudioUnit*)keyboardSequencer.AUAudioUnit setPlaying:true];
    }
}

- (void)stopSequencer {
    playing = false;
    if (drumSequencer != nullptr) {
        [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit setPlaying:false];
    }
    if (keyboardSequencer != nullptr) {
        [(SequencerAudioUnit*)keyboardSequencer.AUAudioUnit setPlaying:false];
    }
}

- (BOOL)isPlaying {
    return playing;
}

- (void)setRepeating:(BOOL)value {
    repeating = value;
    if (keyboardSequencer != nullptr) {
        [(SequencerAudioUnit*)keyboardSequencer.AUAudioUnit setRepeating:value];
    }
}

- (void)addRhythmEvent:(Rhythm2Event *)event {
    SequencerAudioUnit * unit = (SequencerAudioUnit *)[keyboardSequencer AUAudioUnit];
    [unit addEvent: { event.timestamp, 0x90, (uint8_t)event.note, (uint8_t)event.velocity }];
    [unit addEvent: { event.timestamp + event.duration, 0x90, (uint8_t)event.note, 0 }];
}

- (void)removeRhythmEvent:(Rhythm2Event *)event {
    SequencerAudioUnit * unit = (SequencerAudioUnit *)[keyboardSequencer AUAudioUnit];
    [unit deleteEvent: { event.timestamp, 0x90, (uint8_t)event.note, (uint8_t)event.velocity }];
    [unit deleteEvent: { event.timestamp + event.duration, 0x90, (uint8_t)event.note, 0 }];
}

- (void)setChordPattern:(NSDictionary *)dict
{
    SequencerAudioUnit * unit = (SequencerAudioUnit *)[keyboardSequencer AUAudioUnit];

    NSArray * steps = [dict objectForKey:@"steps"];

    for (int i = 0; i < 16; i++) {
        
        if (i < steps.count) {
            
            for (int j = 0; j < 8; j++) {
                NSArray * notes = [[steps objectAtIndex:i] objectForKey:@"notes"];
                if (j < notes.count) {
                    NSDictionary * noteDict = [notes objectAtIndex:j];
                    int note = [[noteDict objectForKey:@"note"] intValue];
                    int type = [[noteDict objectForKey:@"type"] intValue];
                    [unit setChordPatternNote:note type:type stepIndex:i noteIndex:j];
                } else {
                    [unit setChordPatternNote:0 type:127 stepIndex:i noteIndex:j];
                }
            }

        } else {
            for (int j = 0; j < 8; j++) {
                [unit setChordPatternNote:0 type:127 stepIndex:i noteIndex:j];
            }
        }
        
    }
}

- (double)getPlayheadPosition
{
    if (keyboardSequencer != nullptr) {
        return [(SequencerAudioUnit*)keyboardSequencer.AUAudioUnit getPlayheadPosition];
    }
    return 0.0;
}

- (void)setDrumTrack:(NSDictionary *)data
{
    if (drumSequencer != nullptr) {
        [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit setTrack:data];
    }
}

- (NSDictionary *)getDrumTrack:(NSInteger)sequence track:(NSInteger)track
{
    if (drumSequencer != nullptr) {
        [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit getTrack:sequence trackIndex:track];
    }
    return @{};
}

- (void)queueSequence:(NSInteger)index followIndex:(NSInteger)followIndex
{
    if (drumSequencer != nullptr) {
        [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit queueSequence:index followIndex:followIndex];
    }
}

- (NSInteger)getQueuedDrumSequence {
    if (drumSequencer != nullptr) {
        return [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit getQueuedSequence];
    }
    return 0;
}

- (NSInteger)getCurrentDrumSequence {
    if (drumSequencer != nullptr) {
        return [(DrumSequencerAudioUnit*)drumSequencer.AUAudioUnit getCurrentSequence];
    }
    return 0;
}

@end

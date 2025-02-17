//
//  SequencerAudioUnit.h
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "MidiObjects.h"

#define NOTE_ON             0x90
#define NOTE_OFF            0x80
#define MAX_EVENT_COUNT     256
#define BUFFER_LENGTH       16384

@interface SequencerAudioUnit : AUAudioUnit
- (void)addEvent:(MIDIEvent)event;
- (void)deleteEvent:(MIDIEvent)event;
- (void)pressNote:(uint8_t)note;
- (void)releaseNote:(uint8_t)note;
- (void)setRepeating:(BOOL)repeating;
- (double)getPlayheadPosition;
- (void)setPlaying:(BOOL)playing;
- (BOOL)getPlaying;
- (void)setChordPatternNote:(int)note type:(int)type stepIndex:(int)stepIndex noteIndex:(int)noteIndex;
- (void)setTempo:(double)value;

@end

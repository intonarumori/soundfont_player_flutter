//
//  SequencerAudioUnit.h
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface DrumSequencerAudioUnit : AUAudioUnit

- (void)setPlaying:(BOOL)playing;
- (void)setTrack:(NSDictionary *)data;
- (NSDictionary *)getTrack:(NSInteger)sequenceIndex trackIndex:(NSInteger)trackIndex;
- (void)setTempo:(double)value;
- (void)queueSequence:(NSInteger)index followIndex:(NSInteger)followIndex;
- (NSInteger)getCurrentSequence;
- (NSInteger)getQueuedSequence;

@end

//
//  SequencerAudioUnit.h
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface DrumSequencerAudioUnit : AUAudioUnit

- (void)setPlaying:(BOOL)playing;

@end

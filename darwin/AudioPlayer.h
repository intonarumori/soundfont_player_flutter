
#import <Foundation/Foundation.h>

#pragma once

@interface Chord2Event: NSObject

@property (nonatomic, assign) NSInteger root;
@property (nonatomic, assign) NSInteger velocity;
@property (nonatomic, retain) NSArray<NSNumber *> * notes;
@property (nonatomic, assign) double timestamp;
@property (nonatomic, assign) double duration;

@end

@interface Rhythm2Event: NSObject

@property (nonatomic, assign) NSInteger note;
@property (nonatomic, assign) NSInteger velocity;
@property (nonatomic, assign) double timestamp;
@property (nonatomic, assign) double duration;

@end

@interface AudioPlayer : NSObject

- (void)handleMidi:(int)note velocity:(int)velocity;

// API

- (void)playNote:(uint8_t)note velocity:(uint8_t)velocity;
- (void)stopNote:(uint8_t)note;
- (void)loadSoundfont:(NSString *)path;
- (void)loadDrumSoundfont:(NSString *)path;
- (void)startSequencer;
- (void)stopSequencer;
- (BOOL)isPlaying;
- (void)setRepeating:(BOOL)repeating;

- (double)getPlayheadPosition;

- (void)addRhythmEvent:(Rhythm2Event *)event;
- (void)removeRhythmEvent:(Rhythm2Event *)event;

- (void)setChordPattern:(NSDictionary *)dict;


- (void)setDrumTrack:(NSDictionary *)data;
- (NSDictionary *)getDrumTrack:(NSInteger)sequence track:(NSInteger)track;

- (void)queueSequence:(NSInteger)index followIndex:(NSInteger)followIndex;

- (NSInteger)getCurrentDrumSequence;
- (NSInteger)getQueuedDrumSequence;

@end

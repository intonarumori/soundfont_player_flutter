//
//  SequencerAudioUnit.h
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define NOTE_ON             0x90
#define NOTE_OFF            0x80
#define MAX_EVENT_COUNT     256
#define BUFFER_LENGTH       16384

typedef struct MIDIEvent {
    double timestamp;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
} MIDIEvent;

typedef struct MIDISequence {
    double length;
    int eventCount;
    struct MIDIEvent events[MAX_EVENT_COUNT];
} MIDISequence;

void MIDISequenceAddEvent(MIDISequence * sequence, MIDIEvent * event) {
    sequence->events[sequence->eventCount] = *event;
    sequence->eventCount++;
}

void MIDISequenceRemove(double timestamp) {
    
}

typedef struct InternalChordPatternNote {
    int note;
    int type;
} InternalChordPatternNote;

typedef struct InternalChordPatternStep {
    InternalChordPatternNote notes[8];
} InternalChordPatternStep;

typedef struct InternalChordPattern {
    InternalChordPatternStep steps[16];
    int length;
} InternalChordPattern;

// MARK: -

enum SequenceOperationType { Add, Delete };

struct SequenceOperation {
    enum SequenceOperationType type;
    MIDIEvent event;
};

@interface SequencerAudioUnit : AUAudioUnit
- (void)addEvent:(MIDIEvent)event;
- (void)deleteEvent:(MIDIEvent)event;
- (void)pressNote:(uint8_t)note;
- (void)releaseNote:(uint8_t)note;
- (void)setRepeating:(BOOL)repeating;
- (double)getPlayheadPosition;
- (void)setChordPatternNote:(int)note type:(int)type stepIndex:(int)stepIndex noteIndex:(int)noteIndex;
@end

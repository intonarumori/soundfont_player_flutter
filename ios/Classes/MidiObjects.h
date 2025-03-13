
#ifndef MIDIOBJECTS_H_
#define MIDIOBJECTS_H_

#define MAX_EVENT_COUNT     256

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

static void MIDISequenceAddEvent(MIDISequence * sequence, MIDIEvent * event) {
    sequence->events[sequence->eventCount] = *event;
    sequence->eventCount++;
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

#endif

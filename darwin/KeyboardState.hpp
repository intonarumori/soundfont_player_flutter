//
//  KeyboardState.hpp
//  AUv3SequencerExample
//
//  Created by rumori on 2025. 01. 02..
//

#pragma once

#include <stdint.h>

#define NOTES_COUNT (128)

#ifdef __cplusplus

struct KeyboardStateNote {
    int8_t note;
    uint64_t timestamp;
};

class KeyboardState {
public:
    bool isNoteHeld(uint8_t note) {
        return mHeldNotes[note].note > 0;
    }
    
    uint64_t getTimestamp(uint8_t note) {
        return mHeldNotes[note].timestamp;
    }
    
    void releaseNote(uint8_t note) {
        mHeldNotes[note].note = 0;
    }
    
    void pressNote(uint8_t note, uint64_t timestamp) {
        mHeldNotes[note].note = 1;
        mHeldNotes[note].timestamp = timestamp;
    }
    
    int16_t firstPressedNote() {
        for (int i = 0; i < NOTES_COUNT; ++i) {
            if (mHeldNotes[i].note >= 0) {
                return i;
            }
        }
        return -1;
    }
    
private:
    KeyboardStateNote mHeldNotes[NOTES_COUNT];
};

#endif

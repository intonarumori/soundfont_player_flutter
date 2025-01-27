//
//  KeyboardState.hpp
//  AUv3SequencerExample
//
//  Created by rumori on 2025. 01. 02..
//

#pragma once

#include <stdint.h>

#define NOTES_COUNT (128)

class KeyboardState {
public:
    bool isNoteHeld(uint8_t note) {
        return mHeldNotes[note] > 0;
    }
    
    void releaseNote(uint8_t note) {
        mHeldNotes[note] = 0;
    }
    
    void pressNote(uint8_t note) {
        mHeldNotes[note] = 1;
    }
    
    int16_t firstPressedNote() {
        for (int i = 0; i < NOTES_COUNT; ++i) {
            if (mHeldNotes[i] > 0) {
                return i;
            }
        }
        return -1;
    }
    
private:
    uint8_t mHeldNotes[NOTES_COUNT];
};

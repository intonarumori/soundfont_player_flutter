//
//  SequencerKernel.h
//  AUv3SequencerExample
//
//  Created by rumori on 2025. 01. 02..
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
//#import <algorithm>
//#import <vector>
#import <stdio.h>
#import "TPCircularBuffer.h"
#import "KeyboardState.hpp"
#include <mach/mach_time.h>
#import "EventSequence.hpp"

#ifdef __cplusplus

class SequencerKernel {
public:
    SequencerKernel() {
        // initialize FIFO buffer
        TPCircularBufferInit(&fifoBuffer, BUFFER_LENGTH);
       
        sequence = {};
        sequence.eventCount = 0;
        sequence.length = 4;
    }
    
    void initialize(double sampleRate) {
        mSampleRate = sampleRate;
    }
    
    void addEvent(MIDIEvent event) {
        uint32_t availableBytes = 0;
        SequenceOperation *head = (SequenceOperation *)TPCircularBufferHead(&fifoBuffer, &availableBytes);
        SequenceOperation op = { Add, event };
        head = &op;
        TPCircularBufferProduceBytes(&fifoBuffer, head, sizeof(SequenceOperation));
    }

    void deleteEvent(MIDIEvent event) {
        uint32_t availableBytes = 0;
        SequenceOperation *head = (SequenceOperation *)TPCircularBufferHead(&fifoBuffer, &availableBytes);
        SequenceOperation op = { Delete, event };
        head = &op;
        TPCircularBufferProduceBytes(&fifoBuffer, head, sizeof(SequenceOperation));
    }
    
    double getPlayheadPosition() const {
        return mPlayheadPosition;
    }
    
    void pressNote(uint8_t note) {
        heldNotes.pressNote(note, mach_absolute_time());
    }
    
    void releaseNote(uint8_t note) {
        heldNotes.releaseNote(note);
    }
    
    void setRepeating(bool value) {
        mRepeating = value;
    }
    
    void setPlaying(bool value) {
        mPlaying = value;
        totalFrameCount = 0;
    }
    
    bool isPlaying() const {
        return mPlaying;
    }
    
    void setChordNote(int note, int type, int stepIndex, int noteIndex) {
        mPattern.steps[stepIndex].notes[noteIndex].note = note;
        mPattern.steps[stepIndex].notes[noteIndex].type = type;
    }
    
    void setTempo(const double value) {
        mTempo = value;
    }
    
    // MARK: -
    
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    void setMIDIOutputEventBlock(AUMIDIOutputEventBlock midiOutputEventBlock) {
        mMIDIOutputEventBlock = midiOutputEventBlock;
    }
    
    void setTransportStateBlock(AUHostTransportStateBlock transportStateBlock) {
        mTransportStateBlock = transportStateBlock;
    }
    
    AUAudioUnitStatus processWithEvents(AudioUnitRenderActionFlags                 *actionFlags,
                                        const AudioTimeStamp                       *timestamp,
                                        AVAudioFrameCount                           frameCount,
                                        NSInteger                                   outputBusNumber,
                                        AudioBufferList                            *outputData,
                                        const AURenderEvent                        *realtimeEventListHead,
                                        AURenderPullInputBlock __unsafe_unretained pullInputBlock) {
        
        // TEST MIDI
        //        mPlayheadPosition += 0.05;
        //        if (mPlayheadPosition > 2.0) {
        //
        //            uint8_t cable = 0;
        //            uint8_t midiData[] = { 0x90, 60, 100 };
        //            mMIDIOutputEventBlock(AUEventSampleTimeImmediate, cable, sizeof(midiData), midiData);
        //
        //            mPlayheadPosition = 0.0;
        //        }
        //        return noErr;
        
        // move MIDI events from FIFO buffer to internal sequencer buffer
        
        uint64_t blockStartTimestamp = mach_absolute_time();
        
        uint32_t bytes = -1;
        while (bytes != 0) {
            SequenceOperation *op = (SequenceOperation *)TPCircularBufferTail(&fifoBuffer, &bytes);
            if (op) {
                switch (op->type) {
                    case Add: {
                        MIDISequenceAddEvent(&sequence, &op->event);
                        TPCircularBufferConsume(&fifoBuffer, sizeof(SequenceOperation));
                        break;
                    }
                    case Delete: {
                        for (int i = 0; i < sequence.eventCount; i++) {
                            if (sequence.events[i].timestamp == op->event.timestamp) {
                                for (int j = i; j < sequence.eventCount; j++) {
                                    sequence.events[j] = sequence.events[j + 1];
                                }
                                sequence.eventCount--;
                                TPCircularBufferConsume(&fifoBuffer, sizeof(SequenceOperation));
                            }
                        }
                        break;
                    }
                }
            }
        }
                
        //printf("Buffer %f %f\n", bufferStartTime, bufferEndTime);

        // Clear any notes that might have been released
        for (int i = 0; i < 16; i++) {
            int note;
            if (mPlayingNotes.isActiveNote(i, &note)) {
                if (!heldNotes.isNoteHeld(note)) {
                    uint8_t shiftedNote = mPlayingNotes.getShiftedNote(i);
                    mPlayingNotes.deactiveNote(i);
                    uint8_t midiData[] = { 0x80, shiftedNote, 0 };
                    mMIDIOutputEventBlock(AUEventSampleTimeImmediate, 0, sizeof(midiData), midiData);
                }
            }
        }
        
        // Play notes based on incoming midi notes.
        if (!mRepeating) {
            for (int i = 0; i < 128; i++) {
                if (heldNotes.isNoteHeld(i)) {
                    bool hasPlayingNote = false;
                    for (int j = 0; j < 16; j++) {
                        int note;
                        if (mPlayingNotes.isActiveNote(j, &note) && note == i) {
                            hasPlayingNote = true;
                            break;
                        }
                    }
                    
                    if (!hasPlayingNote) {

                        // TODO: use the timestamp to more accurately trigger the midi notes
                        // Since the diff is under 1 ms right now, we can improve this later
                        uint64_t timestamp = heldNotes.getTimestamp(i);
                        uint64_t diffSeconds = blockStartTimestamp > timestamp ? blockStartTimestamp - timestamp : 0;
                        mach_timebase_info_data_t timebase;
                        mach_timebase_info(&timebase);
                        uint64_t milliseconds = diffSeconds * timebase.numer / timebase.denom / NSEC_PER_USEC;
                        printf("Diff timestamp %llu\n", milliseconds);
                        
                        for (int j = 0; j < 16; j++) {
                            int note;
                            if (!mPlayingNotes.isActiveNote(j, &note)) {
                                mPlayingNotes.activateNote(j, i, i);
                                uint8_t midiData[] = { 0x90, (uint8_t)i, 100 };
                                mMIDIOutputEventBlock(AUEventSampleTimeImmediate, 0, sizeof(midiData), midiData);
                                break;
                            }
                        }
                    }
                }
            }
        }
        
        if (!mPlaying) {
            return noErr;
        }
        
        double tempo = mTempo;
        double beatPosition = 0.0;
        
        if (mInternalClock) {
            beatPosition = totalFrameCount / (mSampleRate * 60.0 / tempo);
            totalFrameCount += frameCount;
        } else {
            // get the tempo and beat position from the musical context provided by the host
            mMusicalContextBlock(&tempo, NULL, NULL, &beatPosition, NULL, NULL);
        }
        
        mPlayheadPosition = fmod(beatPosition, sequence.length);
        

        ///
        
        bool transportMoving = false;
        
        if (mInternalClock) {
            transportMoving = true;
        } else {
            AUHostTransportStateFlags transportStateFlags;
            if (mTransportStateBlock(&transportStateFlags, NULL, NULL, NULL)) {
                transportMoving = (transportStateFlags & AUHostTransportStateMoving) != 0;
            }
        }
        if (!transportMoving) return noErr;

        // the length of the sequencer loop in musical time (8.0 == 8 quarter notes)
        double lengthInSamples = sequence.length / tempo * 60. * mSampleRate;
        double beatPositionInSamples = beatPosition / tempo * 60. * mSampleRate;
        
        // the sample time at the start of the buffer, as given by the render block,
        // ...modulo the length of the sequencer loop
        double bufferStartTime = fmod(beatPositionInSamples, lengthInSamples);
        double bufferEndTime = bufferStartTime + frameCount;


        // Using the `mChordPattern` as the basis of repeats
        if (mRepeating)
        {
            // Enumerate the pattern steps
            for (int i = 0; i < 16; i++) {
                
                // Start of the step
                {
                    double eventTime = lengthInSamples / 16 * i;
                    
                    bool eventIsInCurrentBuffer = eventTime >= bufferStartTime && eventTime < bufferEndTime;
                    bool loopsAround = bufferEndTime > lengthInSamples && eventTime < fmod(bufferEndTime, lengthInSamples);
                    
                    if (!(eventIsInCurrentBuffer || loopsAround)) continue;
                    
                    // we should sound the event
                    double offset = eventTime - bufferStartTime;
                    
                    if (loopsAround) {
                        // in case of a loop transitition, add the remaining frames of the current buffer to the offset
                        double remainingFramesInBuffer = lengthInSamples - bufferStartTime;
                        offset = eventTime + remainingFramesInBuffer;
                    }
                    
                    AUEventSampleTime sampleTime = timestamp->mSampleTime + offset;

                    InternalChordPatternStep & step = mPattern.steps[i];
                    
                    for (int k = 0; k < 8; k++) {
                        InternalChordPatternNote & note = step.notes[k];
                        if (note.type > 3) continue;
                        
                        switch (note.type) {
                            case 0: {
                                // play note
                                int noteIndexInChord = note.note;
                                
                                int currentNoteIndex = 0;
                                int playingNote = -1;
                                for (uint8_t note = 0; note < 128; note++) {
                                    if (heldNotes.isNoteHeld(note)) {
                                        if (currentNoteIndex == noteIndexInChord) {
                                            playingNote = note;
                                            break;
                                        }
                                        currentNoteIndex++;
                                    }
                                }
                                
                                if (playingNote > -1) {
                                    // play it
                                    // Find a slot in the playing notes
                                    for (int i = 0; i < 16; i++) {
                                        int note;
                                        if (!mPlayingNotes.isActiveNote(i, &note)) {
                                            mPlayingNotes.activateNote(i, playingNote, playingNote);
                                            uint8_t midiData[] = { 0x90, (uint8_t)playingNote, 100 };
                                            mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
                                            //printf("Triggering note: %d (%llu) %f\n", playingNote, sampleTime, eventTime);
                                            break;
                                        }
                                    }
                                }

                            } break;
                                
                            case 2: {
                                // kill
                                int noteIndexInChord = note.note;
                                
                                int currentNoteIndex = 0;
                                int playingNote = -1;
                                for (uint8_t note = 0; note < 128; note++) {
                                    if (heldNotes.isNoteHeld(note)) {
                                        if (currentNoteIndex == noteIndexInChord) {
                                            playingNote = note;
                                            break;
                                        }
                                        currentNoteIndex++;
                                    }
                                }
                                if (playingNote > -1) {
                                    for (int i = 0; i < 16; i++) {
                                        int note;
                                        if (mPlayingNotes.isActiveNote(i, &note) && note == playingNote) {
                                            uint8_t shiftedNote = mPlayingNotes.getShiftedNote(i);
                                            mPlayingNotes.deactiveNote(i);
                                            uint8_t midiData[] = { 0x80, shiftedNote, 0 };
                                            mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
                                        }
                                    }
                                }
                            } break;
                        }
                    }
                }
                
                // End of the step
                {
                    double eventTime = (lengthInSamples / 16) * i + 4000;
                    
                    bool eventIsInCurrentBuffer = eventTime >= bufferStartTime && eventTime < bufferEndTime;
                    bool loopsAround = bufferEndTime > lengthInSamples && eventTime < fmod(bufferEndTime, lengthInSamples);
                    
                    if (eventIsInCurrentBuffer || loopsAround) {
                        // we should sound the event
                        double offset = eventTime - bufferStartTime;
                        
                        if (loopsAround) {
                            // in case of a loop transitition, add the remaining frames of the current buffer to the offset
                            double remainingFramesInBuffer = lengthInSamples - bufferStartTime;
                            offset = eventTime + remainingFramesInBuffer;
                        }
                        //AUEventSampleTime sampleTime = timestamp->mSampleTime + offset;
                    }
                }
            }
        }
                
        // MIDI
//        AURenderEvent const *nextEvent = realtimeEventListHead;
//        while(nextEvent != NULL) {
//            switch (nextEvent->head.eventType) {
//                case AURenderEventMIDI: {
//                    const AUMIDIEvent & event = nextEvent->MIDI;
//                    if (event.length == 3) {
//                        uint8_t status = event.data[0] & 0xF0;
//                        switch (status) {
//                            case 0x90: // note on
//                            {
//                                uint8_t note = event.data[1];
//                                uint8_t velocity = event.data[2];
//                                printf("midi event NOTE ON %d %d\n", note, velocity);
//                                if (velocity > 0) {
//                                    heldNotes.pressNote(note);
//                                } else {
//                                    heldNotes.releaseNote(note);
//                                }
//                                heldNote = heldNotes.firstPressedNote();
//                            } break;
//                            case 0x80: // note off
//                            {
//                                uint8_t note = event.data[1];
//                                uint8_t velocity = event.data[2];
//                                printf("midi event NOTE OFF %d %d\n", note, velocity);
//                                heldNotes.releaseNote(note);
//                                heldNote = heldNotes.firstPressedNote();
//                            } break;
//                        }
//                    }
//                } break;
//                case AURenderEventMIDIEventList:
//                    printf("midi event list\n");
//                    break;
//                default:
//                    break;
//            }
//            nextEvent = nextEvent->head.next;
//        }
        
        return noErr;
    }
    
private:
    AUHostMusicalContextBlock mMusicalContextBlock;
    AUMIDIOutputEventBlock mMIDIOutputEventBlock;
    AUHostTransportStateBlock mTransportStateBlock;
    
    KeyboardState heldNotes;
    PlayingNotes mPlayingNotes;
    
    InternalChordPattern mPattern;
    
    bool mInternalClock = true;
    bool mPlaying = false;
    bool mRepeating = false;
    bool mRecording = false;
    double mBeatQuantization = 0.25;

    uint32_t totalFrameCount = 0;
    double mTempo = 120.0;
    double mPlayheadPosition = 0.0;
    
    TPCircularBuffer fifoBuffer;
    MIDISequence sequence = {};
    
    double mSampleRate = 44100.0;
};

#endif

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

#ifdef __cplusplus

struct PlayingNote {
    int16_t shiftedNote;
    int16_t eventNote;
    bool active;
};

class SequencerKernel {
public:
    SequencerKernel() {
        // initialize FIFO buffer
        TPCircularBufferInit(&fifoBuffer, BUFFER_LENGTH);
       
        // initialize sequence
        sequence = {};

        // chord mem
//        double rhythm[] = {
//            0.0, 0.5, 0.75,
//            1.0, 1.75,
//            2.0, 2.5,
//            3.25, 3.75,
//        };
//        
//        uint8_t notes[] = { 0 };
//        for (int i = 0; i < sizeof(rhythm) / sizeof(double); i++) {
//            
//            for (int j = 0; j < sizeof(notes); j++) {
//                addEvent({rhythm[i], 0x90, notes[j], 100});
//                addEvent({rhythm[i] + 0.1, 0x80, notes[j], 0});
//            }
//        }

        // ARP
//        uint8_t notes[] = {0,3,7,10};
//        for (int i = 0; i < 16; i++) {
//            uint8_t note = notes[i % sizeof(notes)];
//            addEvent({i * 0.25, 0x90, note, 100});
//            addEvent({i * 0.25 + 0.1, 0x80, note, 0});
//        }

        sequence.eventCount = 0;
        sequence.length = 4;
        
        for (int i = 0; i < 16; i++) {
            mPlayingNotes[i].active = false;
        }
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
        uint32_t bytes = -1;
        while (bytes != 0) {
            SequenceOperation *op = (SequenceOperation *)TPCircularBufferTail(&fifoBuffer, &bytes);
            if (op) {
                switch (op->type) {
                    case Add: {
                        sequence.events[sequence.eventCount] = op->event;
                        sequence.eventCount++;
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

        double tempo = 120.0;
        double beatPosition = 0.0;

        if (mInternalClock) {
            beatPosition = totalFrameCount / (mSampleRate * 60.0 / tempo);
            totalFrameCount += frameCount;
        } else {
            // get the tempo and beat position from the musical context provided by the host
            mMusicalContextBlock(&tempo, NULL, NULL, &beatPosition, NULL, NULL);
        }
        
        mPlayheadPosition = fmod(beatPosition, sequence.length);

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

        for (int i = 0; i < sequence.eventCount; i++) {
            // get the event timestamp, given in musical time (e.g., 1.25)
            MIDIEvent event = sequence.events[i];
            // convert the timestamp to sample time (e.g, 55125)
            double eventTime = event.timestamp / tempo * 60. * mSampleRate;
            
            bool eventIsInCurrentBuffer = eventTime >= bufferStartTime && eventTime < bufferEndTime;
            // there is a loop transition in the current buffer
            bool loopsAround = bufferEndTime > lengthInSamples && eventTime < fmod(bufferEndTime, lengthInSamples);
            
            // check if the event should occur within the current buffer OR there is a loop transition
            if (eventIsInCurrentBuffer || loopsAround) {
                // the difference between the sample time of the event
                // and the beginning of the buffer gives us the offset, in samples
                double offset = eventTime - bufferStartTime;
                
                if (loopsAround) {
                    // in case of a loop transitition, add the remaining frames of the current buffer to the offset
                    double remainingFramesInBuffer = lengthInSamples - bufferStartTime;
                    offset = eventTime + remainingFramesInBuffer;
                }
               
                // pass events to the MIDI output block provided by the host
                AUEventSampleTime sampleTime = timestamp->mSampleTime + offset;
                switch (event.status) {
                    case 0x90: {
                        // Only output notes if we are holding something
                        for (uint8_t note = 0; note < 128; note++) {
                            if (heldNotes.isNoteHeld(note)) {
                                for (int i = 0; i < 16; i++) {
                                    if (!mPlayingNotes[i].active) {
                                        mPlayingNotes[i].active = true;
                                        mPlayingNotes[i].eventNote = note;
                                        mPlayingNotes[i].shiftedNote = note;
                                        uint8_t midiData[] = { event.status, note, event.data2 };
                                        mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
                                        break;
                                    }
                                }
                            }
                        }
                    } break;
                    case 0x80: {
                        for (int i = 0; i < 16; i++) {
                            if (mPlayingNotes[i].active) {
                                mPlayingNotes[i].active = false;
                                uint8_t note = mPlayingNotes[i].shiftedNote;
                                uint8_t midiData[] = { event.status, note, event.data2 };
                                mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
                            }
                        }
                    } break;
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
    
    double getPlayheadPosition() const {
        return mPlayheadPosition;
    }
    
    void pressNote(uint8_t note) {
        heldNotes.pressNote(note);
    }
    
    void releaseNote(uint8_t note) {
        heldNotes.releaseNote(note);
    }
    
    void setRepeating(bool value) {
        mRepeating = value;
    }
private:
    AUHostMusicalContextBlock mMusicalContextBlock;
    AUMIDIOutputEventBlock mMIDIOutputEventBlock;
    AUHostTransportStateBlock mTransportStateBlock;
    
    KeyboardState heldNotes;
    bool mRepeating = false;
    
    bool mInternalClock = true;
    uint32_t totalFrameCount = 0;
    
    double mPlayheadPosition = 0.0;
    
    PlayingNote mPlayingNotes[16];
    
    TPCircularBuffer fifoBuffer;
    MIDISequence sequence = {};
    
    double mSampleRate = 44100.0;
};

#endif

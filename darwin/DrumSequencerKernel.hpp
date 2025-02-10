
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
#import "EventSequence.hpp"

#ifdef __cplusplus

#define BUFFER_LENGTH       16384

class DrumSequencerKernel {
public:
    DrumSequencerKernel() {
        TPCircularBufferInit(&fifoBuffer, BUFFER_LENGTH);
        
        sequences[0].addEvent({0.0, 0x90, 36, 100, 0});
        sequences[0].addEvent({0.3, 0x80, 36, 0, 0});
        sequences[0].addEvent({0.75, 0x90, 36, 100, 1});
        sequences[0].addEvent({0.9, 0x80, 36, 0, 1});
        sequences[0].addEvent({2.0, 0x90, 36, 100, 2});
        sequences[0].addEvent({2.3, 0x80, 36, 0, 2});
        sequences[0].addEvent({2.75, 0x90, 36, 100, 3});
        sequences[0].addEvent({2.9, 0x80, 36, 0, 3});

        sequences[1].addEvent({1.0, 0x90, 37, 100, 0});
        sequences[1].addEvent({1.3, 0x80, 37, 0, 0});
        sequences[1].addEvent({3.0, 0x90, 37, 100, 1});
        sequences[1].addEvent({3.3, 0x80, 37, 0, 1});
        sequences[1].addEvent({3.75, 0x90, 37, 100, 1});
        sequences[1].addEvent({3.9, 0x80, 37, 0, 1});

        for (int i = 0; i < 8; i++) {
            sequences[2].addEvent({i * 0.5, 0x90, 39, 100, 0});
            sequences[2].addEvent({i * 0.5 + 0.2, 0x80, 39, 0, 0});
        }
    }
    
    void initialize(double sampleRate) {
        mSampleRate = sampleRate;
    }
    
    double getPlayheadPosition() const {
        return mPlayheadPosition;
    }
    
    void setPlaying(bool playing) {
        if (playing) totalFrameCount = 0;
        mPlaying = playing;
    }
    
    bool isPlaying() const {
        return mPlaying;
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

        if (!mPlaying) return noErr;
        
        double tempo = 120.0;
        double beatPosition = 0.0;
        
        beatPosition = totalFrameCount / (mSampleRate * 60.0 / tempo);
        totalFrameCount += frameCount;
        
        uint32_t sequenceLength = 4;
        
        mPlayheadPosition = fmod(beatPosition, sequenceLength);
        
        bool transportMoving = true;
        
        if (!transportMoving) return noErr;
        
        // the length of the sequencer loop in musical time (8.0 == 8 quarter notes)
        double lengthInSamples = sequenceLength / tempo * 60. * mSampleRate;
        double beatPositionInSamples = beatPosition / tempo * 60. * mSampleRate;
        
        // the sample time at the start of the buffer, as given by the render block,
        // ...modulo the length of the sequencer loop
        double bufferStartTime = fmod(beatPositionInSamples, lengthInSamples);
        double bufferEndTime = bufferStartTime + frameCount;
        
        //printf("Buffer %f %f\n", bufferStartTime, bufferEndTime);

        // Using the `mChordPattern` as the basis of repeats
        
        for (int sequenceIndex = 0; sequenceIndex < sequenceCount; sequenceIndex++) {

            for (int i = 0; i < sequences[sequenceIndex].eventCount; i++) {
                
                EventSequenceEvent * event = &sequences[sequenceIndex].events[i];
                double eventTime = (event->timestamp / sequenceLength) * lengthInSamples;
                
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
                uint8_t midiData[] = { event->status, event->data1, event->data2 };
                mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
            }
        }
        
        return noErr;
    }
    
private:
    AUHostMusicalContextBlock mMusicalContextBlock;
    AUMIDIOutputEventBlock mMIDIOutputEventBlock;
    AUHostTransportStateBlock mTransportStateBlock;
    
    bool mPlaying = false;
    uint32_t totalFrameCount = 0;
    
    double mPlayheadPosition = 0.0;

    static const int sequenceCount = 3;
    EventSequence sequences[sequenceCount];
    
    TPCircularBuffer fifoBuffer;
    
    double mSampleRate = 44100.0;
};

#endif

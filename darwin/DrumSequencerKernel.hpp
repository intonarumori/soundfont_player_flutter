
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
        
        sequences[0].tracks[0].addEvent({0.0, 0x90, 36, 100, 0});
        sequences[0].tracks[0].addEvent({0.3, 0x80, 36, 0, 0});
        sequences[0].tracks[0].addEvent({0.75, 0x90, 36, 100, 1});
        sequences[0].tracks[0].addEvent({0.9, 0x80, 36, 0, 1});
        sequences[0].tracks[0].addEvent({2.0, 0x90, 36, 100, 2});
        sequences[0].tracks[0].addEvent({2.3, 0x80, 36, 0, 2});
        sequences[0].tracks[0].addEvent({2.75, 0x90, 36, 100, 3});
        sequences[0].tracks[0].addEvent({2.9, 0x80, 36, 0, 3});

        sequences[0].tracks[1].addEvent({1.0, 0x90, 37, 100, 0});
        sequences[0].tracks[1].addEvent({1.3, 0x80, 37, 0, 0});
        sequences[0].tracks[1].addEvent({3.0, 0x90, 37, 100, 1});
        sequences[0].tracks[1].addEvent({3.3, 0x80, 37, 0, 1});
        sequences[0].tracks[1].addEvent({3.75, 0x90, 37, 100, 1});
        sequences[0].tracks[1].addEvent({3.9, 0x80, 37, 0, 1});

        for (int i = 0; i < 8; i++) {
            sequences[0].tracks[2].addEvent({i * 0.5, 0x90, 39, 100, 0});
            sequences[0].tracks[2].addEvent({i * 0.5 + 0.2, 0x80, 39, 0, 0});
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
    
    void setTrack(int sequenceIndex, int trackIndex, Track & track) {
        sequences[sequenceIndex].tracks[trackIndex] = track;
    }
    
    Track & getTrack(int sequenceIndex, int trackIndex) {
        return sequences[sequenceIndex].tracks[trackIndex];
    }
    
    void setTempo(const double value) {
        mTempo = value;
    }
    
    void queueSequence(int index) {
        queuedSequenceIndex = index;
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
        
        double tempo = mTempo;
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
        double bufferStartTimeSamples = fmod(beatPositionInSamples, lengthInSamples);
        double bufferEndTimeSamples = bufferStartTimeSamples + frameCount;
        
        if (bufferEndTimeSamples > lengthInSamples) {
            processEvents(timestamp, currentSequenceIndex, sequenceLength, lengthInSamples, bufferStartTimeSamples, lengthInSamples, 0);
            if (currentSequenceIndex != queuedSequenceIndex) currentSequenceIndex = queuedSequenceIndex;
            double remainingFramesInBuffer = lengthInSamples - bufferStartTimeSamples;
            processEvents(timestamp, currentSequenceIndex, sequenceLength, lengthInSamples, 0, fmod(bufferEndTimeSamples, lengthInSamples), remainingFramesInBuffer);
        } else {
            processEvents(timestamp, currentSequenceIndex, sequenceLength, lengthInSamples, bufferStartTimeSamples, bufferEndTimeSamples, 0);
        }
        
        //printf("Buffer %f %f\n", bufferStartTimeSamples, bufferEndTimeSamples);

        return noErr;
    }
    
    inline void processEvents(const AudioTimeStamp *timestamp,
                              int sequenceIndex, double sequenceLength, double lengthInSamples,
                              double bufferStartTimeSamples, double bufferEndTimeSamples,
                              double eventOffset)
    {
        Sequence & sequence = sequences[sequenceIndex];
        
        for (int trackIndex = 0; trackIndex < sequence.numberOfTracks; trackIndex++) {

            for (int i = 0; i < sequence.tracks[trackIndex].eventCount; i++) {
                
                TrackEvent * event = &sequence.tracks[trackIndex].events[i];
                double eventTime = (event->timestamp / sequenceLength) * lengthInSamples;
                
                bool eventIsInCurrentBuffer = eventTime >= bufferStartTimeSamples && eventTime < bufferEndTimeSamples;
                
                if (!(eventIsInCurrentBuffer)) continue;
                
                double offset = eventTime - bufferStartTimeSamples + eventOffset;
                
                AUEventSampleTime sampleTime = timestamp->mSampleTime + offset;
                uint8_t midiData[] = { event->status, event->data1, event->data2 };
                mMIDIOutputEventBlock(sampleTime, 0, sizeof(midiData), midiData);
            }
        }
    }
    
private:
    AUHostMusicalContextBlock mMusicalContextBlock;
    AUMIDIOutputEventBlock mMIDIOutputEventBlock;
    AUHostTransportStateBlock mTransportStateBlock;
    
    bool mPlaying = false;
    uint32_t totalFrameCount = 0;
    
    double mPlayheadPosition = 0.0;
    
    double mTempo = 120.0;

    static const int numberOfSequences = 6;
    int currentSequenceIndex = 0;
    int queuedSequenceIndex = 0;
    Sequence sequences[numberOfSequences];
    
    TPCircularBuffer fifoBuffer;
    
    double mSampleRate = 44100.0;
};

#endif

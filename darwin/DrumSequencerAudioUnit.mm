#import "DrumSequencerAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>
#import <CoreMIDI/CoreMIDI.h>
#import "TPCircularBuffer.h"
#import "DrumSequencerKernel.hpp"

@interface DrumSequencerAudioUnit ()

@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property (nonatomic, readwrite) AUParameter *playheadParameter;

@end

@implementation DrumSequencerAudioUnit {
    DrumSequencerKernel _kernel;
}

@synthesize parameterTree = _parameterTree;
@synthesize playheadParameter = _playheadParameter;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
    // // TODO: these become available later for some reason
    _kernel.setMIDIOutputEventBlock(self.MIDIOutputEventBlock);
    _kernel.setMusicalContextBlock(self.musicalContextBlock);
    _kernel.setTransportStateBlock(self.transportStateBlock);
    _kernel.initialize(_outputBus.format.sampleRate);
    
    // initialize output bus
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
    _outputBus.maximumChannelCount = 8;
    
    // then an array with it
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];
    [self createParameterTree];
    
    return self;
}

- (void)createParameterTree {
    _playheadParameter = [AUParameterTree createParameterWithIdentifier:@"playhead"
                                                                     name:@"Playhead"
                                                                  address:0
                                                                      min:0.0
                                                                      max:100.0
                                                                     unit:kAudioUnitParameterUnit_Generic
                                                                 unitName:nil
                                                                    flags:0
                                                             valueStrings:nil
                                                      dependentParameters:nil];
  _parameterTree = [AUParameterTree createTreeWithChildren:@[_playheadParameter]];

  // A function to provide string representations of parameter values.
  _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
    switch (param.address) {
      default:
        return @"?";
    }
  };
}

#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    [super allocateRenderResourcesAndReturnError:outError];
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    [super deallocateRenderResources];
}

#pragma mark - User code

- (void)setPlaying:(BOOL)playing
{
    _kernel.setPlaying(playing);
}

- (void)setTrack:(NSDictionary *)data
{
    Track track;
    
    int sequenceIndex = [[data objectForKey:@"sequence"] intValue];
    int trackIndex = [[data objectForKey:@"track"] intValue];
    NSArray* events = [data objectForKey:@"events"];
    for (NSDictionary * event in events) {
        double timestamp = [[event objectForKey:@"timestamp"] doubleValue];
        double duration = [[event objectForKey:@"duration"] doubleValue];
        int note = [[event objectForKey:@"note"] intValue];
        int velocity = [[event objectForKey:@"velocity"] intValue];
        track.addEvent({timestamp, 0x90, (uint8_t)note, (uint8_t)velocity, 0});
        track.addEvent({timestamp + duration, 0x80, (uint8_t)note, (uint8_t)velocity, 0});
    }
    _kernel.setTrack(sequenceIndex, trackIndex, track);
}

- (NSDictionary *)getTrack:(NSInteger)sequenceIndex trackIndex:(NSInteger)trackIndex {
    Track & track = _kernel.getTrack((int)sequenceIndex, (int)trackIndex);
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSNumber numberWithInteger:sequenceIndex] forKey:@"sequence"];
    [dict setObject:[NSNumber numberWithInteger:trackIndex] forKey:@"track"];
    
    NSMutableArray * array = [NSMutableArray array];
    for (int i = 0; i < track.eventCount; i++) {
        TrackEvent & event = track.events[i];
        if (event.status == 0x90) {
            // TODO: proper handling of duration
            [array addObject:@{
                @"timestamp": [NSNumber numberWithDouble:event.timestamp],
                @"note": [NSNumber numberWithInt:event.data1],
                @"velocity": [NSNumber numberWithInt:event.data2],
                @"duration": [NSNumber numberWithDouble:0.1],
            }];
        }
    }
    [dict setObject:array forKey:@"events"];
    
    return dict;
}

- (void)setTempo:(double)value
{
    _kernel.setTempo(value);
}

- (void)queueSequence:(NSInteger)index followIndex:(NSInteger)followIndex
{
    _kernel.queueSequence((int)index, (int)followIndex);
}

- (NSInteger)getCurrentSequence {
    return _kernel.getCurrentSequence();
}

- (NSInteger)getQueuedSequence {
    return _kernel.getQueuedSequence();
}

#pragma mark - MIDI

- (NSArray<NSString *>*) MIDIOutputNames {
    return @[@"midiOut"];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    
    // cache the musical context and MIDI output blocks provided by the host
//    __block TPCircularBuffer buffer = self->_fifoBuffer;
    
    __block AUHostMusicalContextBlock musicalContextBlock = self.musicalContextBlock;
    __block AUMIDIOutputEventBlock midiOutputBlock = self.MIDIOutputEventBlock;
    __block AUHostTransportStateBlock transportStateBlock = self.transportStateBlock;
    
    // get the current sample rate from the output bus
    __block double sampleRate = self.outputBus.format.sampleRate;
    
    __block DrumSequencerAudioUnit * audioUnit = self;
    __block DrumSequencerKernel * kernel = &_kernel;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
                              const AudioTimeStamp       				*timestamp,
                              AVAudioFrameCount           				frameCount,
                              NSInteger                   				outputBusNumber,
                              AudioBufferList            				*outputData,
                              const AURenderEvent        				*realtimeEventListHead,
                              AURenderPullInputBlock __unsafe_unretained pullInputBlock) {

        kernel->initialize(sampleRate);
        kernel->setMIDIOutputEventBlock(midiOutputBlock);
        kernel->setMusicalContextBlock(musicalContextBlock);
        kernel->setTransportStateBlock(transportStateBlock);
        auto result = kernel->processWithEvents(actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock);
        audioUnit.playheadParameter.value = kernel->getPlayheadPosition();
        return result;
    };
}

@end

#ifndef MIDI_HANDLER_HPP
#define MIDI_HANDLER_HPP

#include <CoreMIDI/CoreMIDI.h>

#ifdef __cplusplus

class MidiHandler {
public:
    using MidiCallback = void (*)(void * ref, int note, int velocity);
    
    MidiHandler() {}
    ~MidiHandler() {}

    void startSession();
    void stopSession();
    void handleMidiMessage(const MIDIPacketList *packetList);
    void processMidiMessage(const Byte *data, size_t length);
    
    void setCallback(MidiCallback callback, void * ref) {
        mCallback = callback;
        mCallbackRef = ref;
    }

private:
    MIDIClientRef midiClient;
    MIDIPortRef midiInputPort;
    MIDIPortRef midiOutputPort;
    MIDIEndpointRef midiEndpoint;
    MidiCallback mCallback = nullptr;
    void * mCallbackRef = nullptr;
        
    static void midiReadCallback(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
};

#endif

#endif // MIDI_HANDLER_HPP

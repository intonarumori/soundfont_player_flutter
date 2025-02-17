#include "MidiHandler.hpp"
#include <CoreMIDI/CoreMIDI.h>
#include <iostream>

static void midiReadProc(const MIDIPacketList *packetList,
                         void *readProcRefCon,
                         void *srcConnRefCon) {
    MidiHandler *handler = static_cast<MidiHandler *>(readProcRefCon);
    handler->handleMidiMessage(packetList);
}

void MidiHandler::startSession() {
    OSStatus status;
    status = MIDIClientCreate(CFSTR("Soundfont Client"), nullptr, nullptr, &midiClient);
    //status = MIDIInputPortCreate(midiClient, CFSTR("MIDI Input Port"), midiReadProc, this, &midiInputPort);
    //status = MIDIOutputPortCreate(midiClient, CFSTR("MIDI Output Port"), &midiOutputPort);
    
    MIDIDestinationCreate(midiClient, CFSTR("SoundFont input"), midiReadProc, this, &midiOutputPort);
}

void MidiHandler::stopSession() {
    MIDIClientDispose(midiClient);
}

void MidiHandler::handleMidiMessage(const MIDIPacketList *packetList) {
    const MIDIPacket *packet = packetList->packet;
    for (unsigned int i = 0; i < packetList->numPackets; ++i) {
        // Process each MIDI message
        processMidiMessage(packet->data, packet->length);
        packet = MIDIPacketNext(packet);
    }
}

void MidiHandler::processMidiMessage(const Byte *data, size_t length) {
    // Implement MIDI message processing logic here
    if (length == 3) {
        if (data[0] == 0x90) {
            if (mCallback != nullptr) {
                mCallback(mCallbackRef, data[1], data[2]);
            }
        } else if (data[0] == 0x80) {
            if (mCallback != nullptr) {
                mCallback(mCallbackRef, data[1], 0);
            }
        }
    }
    return;
    
    std::cout << "Received MIDI message: ";
    for (int i = 0; i < length; ++i) {
        std::cout << static_cast<int>(data[i]) << " ";
    }
    std::cout << std::endl;
}

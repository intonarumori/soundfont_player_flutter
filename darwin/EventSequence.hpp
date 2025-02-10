
#pragma once

#ifdef __cplusplus

#define MAX_EVENT_COUNT 128

typedef struct EventSequenceEvent {
    double timestamp;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    uint8_t userData;
} EventSequenceEvent;

class EventSequence {
  
public:
    EventSequence() {
        length = 4;
        eventCount = 0;
    }
    ~EventSequence() {}
    
    void addEvent(EventSequenceEvent event) {
        events[eventCount] = event;
        eventCount++;
    }
    
    int eventIndexWithTimestamp(double timestamp) {
        for (int i = 0; i < eventCount; i++) {
            if (events[i].timestamp == timestamp) {
                return i;
            }
        }
        return -1;
    }

    void removeEventAtIndex(int index) {
        for (int j = index; j < eventCount; j++) {
            events[j] = events[j + 1];
        }
        eventCount--;
    }
    
    double length;
    int eventCount;
    EventSequenceEvent events[MAX_EVENT_COUNT];
};

#endif

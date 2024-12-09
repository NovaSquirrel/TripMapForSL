/*
Trip logging script for Second Life
Copyright (c) 2024 NovaSquirrel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
#define MINIMUM_DISTANCE_REQUIRED 2.5
#define TIMER_FREQUENCY 2
#define MAX_RECORD_LENGTH 5000
#define REGION_LOG_LENGTH 5

string region_name;       // Used to detect when crossing into a new region
vector last_position;     // Most recent recorded point's position
string current_record;    // Region x, region y, sequence of XXYY pairs
integer record_count = 0; // How many records are in the linkset data
integer active = 0;       // Actively recording
integer paused = 0;       // Paused recording
integer total_points = 0; // Amount of points that have been recorded
integer total_linkset_data_available; // bytes available when all data is deleted
integer did_pause = 0;    // Set to 1 if the recording was paused, to record that
list region_log;

integer dialog_channel;   // Buttons
integer marker_channel;   // Text input
integer listener;         // Listener handle for either channel
integer configure_mode;   // If nonzero, the marker input is actually for configuration

// Configuration
integer timer_frequency = TIMER_FREQUENCY;
float minimum_distance_required = MINIMUM_DISTANCE_REQUIRED;

string encode_byte(integer n) {
    if(n < 0)
        n = 0;
    if(n > 255)
        n = 255;
    return llChar(n+0xA1);
}

init_record(string prefix) {
    write_current_record();
    region_name = llGetRegionName();
    vector corner = llGetRegionCorner();
    integer region_x = (integer)(corner.x / 256);
    integer region_y = (integer)(corner.y / 256);
    current_record = prefix+encode_byte(region_x&255) + encode_byte(region_x>>8) + encode_byte(region_y&255) + encode_byte(region_y>>8);
    if(did_pause) {
        current_record = "-\n" + current_record;
        did_pause = 0;
    }
}

add_coordinate_to_record(vector coordinate) {
    last_position = coordinate;
    current_record += encode_byte((integer)llFloor(coordinate.x)) + encode_byte((integer)(llFloor(coordinate.y)));
    total_points += 1;
}

write_current_record() {
    if(current_record == "")
        return;
    if(llLinksetDataWrite((string)record_count, current_record) == LINKSETDATA_EMEMORY) {
        llOwnerSay("Ending this trip due to a lack of memory");
        active = 0;
    }
    record_count += 1;
    region_name = ""; // Make the next point fetch the region again
    current_record = "";
}

default {
    timer() {
        if(active == 0 || paused == 1)
            return;
        // Start a new record if the user is in a new region
        if(llGetRegionName() != region_name || llStringLength(current_record) > MAX_RECORD_LENGTH) {
            init_record("+");
            add_coordinate_to_record(llGetRootPosition());
            return;
        }
        vector current_position = llGetRootPosition();
        if(llSqrt(llPow(current_position.x-last_position.x, 2)+llPow(current_position.y-last_position.y, 2)) > minimum_distance_required) {
            add_coordinate_to_record(current_position);
        }
    }
    
    changed(integer change) {
        if ((change & CHANGED_TELEPORT) && active && !paused) {
            region_name = "";
            did_pause = 1;
        }
        if (change & CHANGED_REGION) {
            region_log = [llGetRegionName()] + region_log;
            if(llGetListLength(region_log) > REGION_LOG_LENGTH) {
                region_log = llList2List(region_log, 0, REGION_LOG_LENGTH-1);
            }
        }
    }

    state_entry() {
        dialog_channel = (integer)(llFrand(-1000000000.0) - 1000000000.0);
        marker_channel = dialog_channel + 1;
        llSetTimerEvent(TIMER_FREQUENCY);
    }
    
    touch_start(integer total_number) {
        llListenRemove(listener);
        listener = llListen(dialog_channel, "", llDetectedKey(0), "");
        string message = "Not currently recording";
        if(active) {
            message = "Points recorded: " + (string)total_points+" points\nMemory usage: " + (string)(100-(integer)((float)llLinksetDataAvailable()/(float)total_linkset_data_available*100+0.5)) + "%";
            if(paused) {
                message += "\n(Paused)";
            }
        }
        message += "\n\nConfiguration: Record every " + (string)timer_frequency + " seconds, if you've moved " + (string)minimum_distance_required + " meters";
     
        llDialog(llDetectedKey(0), message, [
        llList2String(["Start!", "Finish"], active), 
        llList2String(["Pause", "Resume"], paused),
        "Cancel", "Get data", "Add marker", "Configure", "How to use", "Region log"
        ], dialog_channel);
    }
    
    listen(integer channel, string name, key id, string option) {
        llListenRemove(listener);
        if(channel == dialog_channel) {
            if(option == "Start!") {
                llLinksetDataReset();
                total_linkset_data_available = llLinksetDataAvailable();
                region_name = "";
                current_record = "";
                total_points = 0;
                record_count = 0;
                active = 1;
                paused = 0;
                did_pause = 0;
                llOwnerSay("Started recording!");
            } else if(option == "Finish") {
                write_current_record();
                active = 0;
                llOwnerSay("Stopped recording at "+(string)total_points+" points!");
            } else if(option == "Pause") {
                region_name = "";
                paused = 1;
                did_pause = 1;
                llOwnerSay("Pausing");
            } else if(option == "Resume") {
                paused = 0;
                llOwnerSay("Unpausing");
            } else if(option == "Get data") {
                write_current_record();
                llMessageLinked(LINK_THIS, record_count, "show_url", "");
            } else if(option == "Add marker") {
                llTextBox(id, "Add a marker with this text:", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 0;
            } else if(option == "Configure") {
                llTextBox(id, "How frequently (in seconds) should points be recorded? Default is 2", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 1;
            } else if(option == "How to use") {
                llDialog(id, "Choose \"Start!\" from the menu when you'd like to start recording a trip, then \"Finish\" when you'd like to stop.\nDuring your trip you can add points of interest where you're currently standing by adding markers.\n\"Get data\" will give you a link to a URL that will show the data you recorded, as well as a URL to a tool to copy it into.\nThere may be multiple pages of data, in which case you'd copy all of them.\nSetting the recording frequency to be faster makes lines smoother, and slower allows for longer trips.", ["OK"], dialog_channel);
            } else if(option == "Region log") {
                llDialog(id, "Regions you've recently been in:\n" + llList2CSV(region_log), ["OK"], dialog_channel);
            }
        } else if(channel == marker_channel) {
            if(configure_mode == 0) {
                init_record("!");
                add_coordinate_to_record(llGetRootPosition());
                current_record += llReplaceSubString(option, "\n", "<br>", 0);
                write_current_record();
            } else if(configure_mode == 1) {
                timer_frequency = (integer)option;
                llSetTimerEvent(timer_frequency);
                llTextBox(id, "How far in meters should you have to move before another point is recorded? Default is 2.5", marker_channel);
                listener = llListen(marker_channel, "", id, "");
                configure_mode = 2;
            } else if(configure_mode == 2) {
                minimum_distance_required = (float)option;
                configure_mode = 0;
            }
        }
    }
}

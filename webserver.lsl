/*
Trip logging script for Second Life
(Web server utility script)
Copyright 2024, NovaSquirrel

Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.
*/
#define PAGINATION_THRESHOLD 11000

string  url;
key     url_request_id;
integer record_count;

request_url() {
    llReleaseURL(url);
    url_request_id = llRequestURL();
}

try_show_url() {
    if(url != "") {
        llLoadURL(llGetOwner(), "Visit the above URL to get your data, then paste it into https://novasquirrel.github.io/TripMapForSL/", url);
    } else {
        request_url();
    }
}

default {
    attach(key id) {
        url = "";
    }
    
    changed(integer change) {
        if (change & (CHANGED_OWNER | CHANGED_REGION | CHANGED_REGION_START | CHANGED_TELEPORT)) {
            url = "";
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        if(str == "show_url") {
            record_count = num;
            try_show_url();
        }
    }
    
    http_request(key id, string method, string body) {
        if (id == url_request_id) {
            if (method == URL_REQUEST_DENIED)
                llOwnerSay("The following error occurred while attempting to get a free URL for this device:\n \n" + body);
            else if (method == URL_REQUEST_GRANTED) {
                url = body;
                try_show_url();
            }
        } else if (method == "GET") {
            string path = llGetHTTPHeader(id, "x-path-info");
            integer i = 0;
            if(path != "")
                i = (integer)llGetSubString(path, 1, -1);
            
            string output = "format=base256\n";
            for(; i<record_count; i++) {
                output += llLinksetDataRead((string)i) + "\n";
                if(llGetFreeMemory() < PAGINATION_THRESHOLD && (i != record_count-1)) {
                    llHTTPResponse(id, 200, "# Get more data at "+url+"/"+(string)(i+1)+"\n"+output);
                    return;
                }
            }
            llHTTPResponse(id, 200, output);
        } else {
            llHTTPResponse(id, 405, "Method unsupported");
        }
    }
}

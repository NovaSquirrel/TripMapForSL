/*
Trip logging script for Second Life
(Path viewer)
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

let drawnElements = [];
let slmap;
let format = 'hex';
let formatCoordSize = 4;
let allPolylines = [];

const start_icon = L.icon({
	iconUrl: 'start_marker.png',
	iconSize: [9, 9]
});
const message_icon = L.icon({
	iconUrl: 'message_marker.png',
	iconSize: [9, 9]
});
const end_icon = L.icon({
	iconUrl: 'end_marker.png',
	iconSize: [9, 9]
});

function readCoordinatePairX(pair) {
	if(format == 'hex') {
		return parseInt(pair.substring(0, 2), 16);
	} else if(format == 'base256') {
		return (pair.charCodeAt(0)-32);
	}
}

function readCoordinatePairY(pair) {
	if(format == 'hex') {
		return parseInt(pair.substring(2, 4), 16);
	} else if(format == 'base256') {
		return (pair.charCodeAt(1)-32);
	}
}

function render() {
	slmap = slmap ?? SLMap(document.getElementById('map-container'));

	// Parse the data and keep track of all of the coordinates
	let currentLine = [];
	const tripCoordinates = [currentLine];	
	const tripMarkers = [];
	const dataLines = document.getElementById('tripData').value.split('\n');
	for(let record of dataLines) {
		if(record.startsWith('#') || record.trim() == '') {
			continue
		} else if(record.startsWith('format=')) {
			if(record == 'format=hex') {
				format = 'hex';
				formatCoordSize = 4;
			} else if(record == 'format=base256') {
				format = 'base256';
				formatCoordSize = 2;				
			} else {
				console.log('Invalid data format '+format);
				return;
			}
			// Sometimes a point will be recorded before the script realizes a teleport happened. Scan for and fix this.
			for(let i in dataLines) {
				i = parseInt(i);
				if(dataLines[i].startsWith('+') && dataLines[i].length == (1+formatCoordSize*3) && (i+2 < dataLines.length) && dataLines[i+1].startsWith('-') && dataLines[i+2].startsWith(dataLines[i])) {
					dataLines[i] = '';
				}
			}
		} else if(record.startsWith('+')) { // Coordinates
			record = record.substring(1);
			const regionXText = record.substring(0, formatCoordSize);
			const regionX = readCoordinatePairX(regionXText) + readCoordinatePairY(regionXText)*256;
			const regionYText = record.substring(formatCoordSize, formatCoordSize*2);
			const regionY = readCoordinatePairX(regionYText) + readCoordinatePairY(regionYText)*256;
			record = record.substring(formatCoordSize*2);
			for(let pairCount = 0; pairCount < record.length / formatCoordSize; pairCount++) {
				const pair = record.substring(pairCount*formatCoordSize, (pairCount+1)*formatCoordSize);
				currentLine.push([regionY+readCoordinatePairY(pair)/256, regionX+readCoordinatePairX(pair)/256]);
			}
		} else if(record.startsWith('-')) { // Break
			currentLine = [];
			tripCoordinates.push(currentLine);
		} else if(record.startsWith('!')) { // Marker
			record = record.substring(1);
			const regionXText = record.substring(0, formatCoordSize);
			const regionX = readCoordinatePairX(regionXText) + readCoordinatePairY(regionXText)*256;
			const regionYText = record.substring(formatCoordSize, formatCoordSize*2);
			const regionY = readCoordinatePairX(regionYText) + readCoordinatePairY(regionYText)*256;
			record = record.substring(formatCoordSize*2);
			const coords = record.substring(0, formatCoordSize);
			tripMarkers.push([[regionY+readCoordinatePairY(coords)/256, regionX+readCoordinatePairX(coords)/256], record.substring(formatCoordSize)]);
		}
	}

	// Clear out old lines and markers
	for(const e of drawnElements) {
		e.remove();
	}
	drawnElements = [];
	allPolylines = [];

	// Draw a line across the paths, add the start/end markers, and any additonal markers
	let firstPolyline = undefined;
	for(const line of tripCoordinates) {
		if(line.length == 0)
			continue;
		const polyline = L.polyline(line, {
			color: document.getElementById('lineColor').value,
			weight: parseFloat(document.getElementById('lineWeight').value)
		}).addTo(slmap);
		drawnElements.push(polyline);
		if(document.getElementById('showStartEnd').checked) {
			drawnElements.push(L.marker(line[0], {icon: start_icon}).addTo(slmap));
			drawnElements.push(L.marker(line[line.length-1], {icon: end_icon}).addTo(slmap));
		}
		allPolylines.push(polyline);
	}

	// Add markers to the map and the picker
	let markerPicker = document.getElementById("markerPicker");
	while (markerPicker.firstChild) {
		markerPicker.removeChild(markerPicker.firstChild);
	}
	for(const markerData of tripMarkers) {
		const marker = L.marker(markerData[0], {icon: message_icon}).addTo(slmap)
		const popup = L.popup().setContent(markerData[1]);
		marker.bindPopup(popup);
		drawnElements.push(marker);
		
		const el = document.createElement("option");
		el.textContent = markerData[1];
		el.value = JSON.stringify(markerData[0]);
		markerPicker.appendChild(el);
	}

	// Line picker
	const linePicker = document.getElementById("polylinePicker");
	linePicker.value = "1";
	linePicker.min = "1";
	linePicker.max = allPolylines.length;

	if(allPolylines.length !== 0)
		slmap.fitBounds(allPolylines[0].getBounds());
}

function goToLine() {
	const picked = document.getElementById("polylinePicker").value;
	if(picked > 0 && picked <= allPolylines.length) {
		slmap.fitBounds(allPolylines[picked-1].getBounds());
	}
}

function goToMarker() {
	const value = document.getElementById("markerPicker").value;
	if(value == "")
		return;
	slmap.setView(JSON.parse(value));
}

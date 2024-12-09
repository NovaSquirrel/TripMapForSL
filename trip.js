/*
Trip logging script for Second Life
(Path viewer)
Copyright 2024, NovaSquirrel

Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.
*/

let drawnElements = [];
let slmap;
let format = 'hex';
let formatCoordSize = 4;

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
	const tripCoordinates = [];
	const tripMarkers = [];
	for(let record of document.getElementById('tripData').value.split('\n')) {
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
		} else if(record.startsWith('+')) { // Coordinates
			record = record.substring(1);
			const regionXText = record.substring(0, formatCoordSize);
			const regionX = readCoordinatePairX(regionXText) + readCoordinatePairY(regionXText)*256;
			const regionYText = record.substring(formatCoordSize, formatCoordSize*2);
			const regionY = readCoordinatePairX(regionYText) + readCoordinatePairY(regionYText)*256;
			record = record.substring(formatCoordSize*2);
			for(let pairCount = 0; pairCount < record.length / formatCoordSize; pairCount++) {
				const pair = record.substring(pairCount*formatCoordSize, (pairCount+1)*formatCoordSize);
				tripCoordinates.push([regionY+readCoordinatePairY(pair)/256, regionX+readCoordinatePairX(pair)/256]);
			}
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

	// Draw a line across the path, add the start/end markers, and any additonal markers
	const polyline = L.polyline(tripCoordinates, {
		color: document.getElementById('lineColor').value,
		weight: parseFloat(document.getElementById('lineWeight').value)
	}).addTo(slmap);
	drawnElements.push(polyline);
	drawnElements.push(L.marker(tripCoordinates[0], {icon: start_icon}).addTo(slmap));
	drawnElements.push(L.marker(tripCoordinates[tripCoordinates.length-1], {icon: end_icon}).addTo(slmap));
	for(const markerData of tripMarkers) {
		const marker = L.marker(markerData[0], {icon: message_icon}).addTo(slmap)
		const popup = L.popup().setContent(markerData[1]);
		marker.bindPopup(popup);
		drawnElements.push(marker);
	}
	slmap.fitBounds(polyline.getBounds());
}

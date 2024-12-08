let drawnElements = [];
let slmap;

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

function render() {
	slmap = slmap ?? SLMap(document.getElementById('map-container'));

	// Parse the data and keep track of all of the coordinates
	const tripCoordinates = [];
	const tripMarkers = [];
	for(let record of document.getElementById('tripData').value.split('\n')) {
		record = record.split(',');
		if(record.length < 2)
			continue;
		const regionX = parseInt(record[0]);
		const regionY = parseInt(record[1]);
		const recordCoordinates = record[2].split('!');
		if(recordCoordinates.length == 1) { // Regular coordinate
			for(let pairCount = 0; pairCount < recordCoordinates[0].length / 4; pairCount++) {
				const pair = recordCoordinates[0].substring(pairCount*4, (pairCount+1)*4);
				const pairX = parseInt(pair.substring(0, 2), 16)/256;
				const pairY = parseInt(pair.substring(2, 4), 16)/256;
				tripCoordinates.push([regionY+pairY, regionX+pairX]);
			}
		} else if(recordCoordinates.length == 2) { // Marker
			const pairX = parseInt(recordCoordinates[0].substring(0, 2), 16)/256;
			const pairY = parseInt(recordCoordinates[0].substring(2, 4), 16)/256;
			tripMarkers.push([[regionY+pairY, regionX+pairX], recordCoordinates[1]]);
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

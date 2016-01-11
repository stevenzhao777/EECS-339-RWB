//tanxy
// Global state
//
// map     - the map object
// usermark- marks the user's position on the map
// markers - list of markers on the current map (not including the user position)
// 
//

//
// First time run: request current location, with callback to Start
//



if (navigator.geolocation)  {
    navigator.geolocation.getCurrentPosition(Start);
}


function UpdateMapById(id, tag) {
   	var target = document.getElementById(id);
    var data = target.innerHTML;

    var rows  = data.split("\n");
   
    for (i in rows) {
	var cols = rows[i].split("\t");
	var lat = cols[0];
	var long = cols[1];

	markers.push(new google.maps.Marker({ map:map,
						    position: new google.maps.LatLng(lat,long),
						    title: tag+"\n"+cols.join("\n")}));
	
    }
}

function ClearMarkers()
{
    // clear the markers
    while (markers.length>0) { 
	markers.pop().setMap(null);
    }
}


function UpdateMap()
{
    var color = document.getElementById("color");
	
    color.innerHTML="<b><blink>Updating Display...</blink></b>";
    color.style.backgroundColor='white';

    ClearMarkers();

	//----------------------------------------------
		
	
	if($('#committee').is(':checked')){

	    UpdateMapById("committee_data","COMMITTEE");
			$('#dem_comm_money').html($('#dem_committee-contributions').text());
			$('#rep_comm_money').html($('#rep_committee-contributions').text());
			$('#dem_comm_count').html($('#dem_committee-contributions_count').text());
			$('#rep_comm_count').html($('#rep_committee-contributions_count').text());
			$('#comm').css('background-color',$('#dem_committee-contributions').attr('color'));
	};

	if($('#candidate').is(':checked')){
		console.log("$#%@#%#@$");
	    UpdateMapById("candidate_data","CANDIDATE");};
	

	if($('#individual').is(':checked')){
	    UpdateMapById("individual_data","INDIVIDUAL");
			$('#dem_indv_money').html($('#dem_individual-contributions').text());
			$('#rep_indv_money').html($('#rep_individual-contributions').text());
			$('#dem_indv_count').html($('#dem_individual-contributions_count').text());
			$('#rep_indv_count').html($('#rep_individual-contributions_count').text());
			$('#indv').css('background-color',$('#dem_individual-contributions').attr('color'));
	};

	if($('#opinion').is(':checked')){
	    UpdateMapById("opinion_data","OPINION");
	$('#std').html($('#h_std').text());
$('#avg').html($('#h_avg').text());
$('#dem_o').html($('#h_dem_o').text());
$('#rep_o').html($('#h_rep_o').text());
$('#opn').css('background-color',$('#h_rep_o').attr('color'));

console.log($('#std').text(),
$('#avg').text(),
$('#dem_o').text(),
$('#rep_o').text());

};
	//-----------------------------------------------

    color.innerHTML="Ready";
    
    if (Math.random()>0.5) { 
	color.style.backgroundColor='blue';
    } else {
	color.style.backgroundColor='red';
    }
   
}

function NewData(data)
{
  var target = document.getElementById("data");
  
  target.innerHTML = data;

  UpdateMap();

}

function SelectedCycles() {
  var Cycles = document.getElementById('cycles');
  
  var array = [];
  for (var i=0;i<Cycles.options.length;i++) {
    if (Cycles.options[i].selected == true) {
      array.push("'"+Cycles.options[i].value.toString()+"'");
    }
  }
	//var last = array[array.length-1];
	//array[array.length-1] =last.substring(0, last.length-1);

  return array;
}


function ViewShift()
{	

  var bounds = map.getBounds();

  var ne = bounds.getNorthEast();
  var sw = bounds.getSouthWest();

  var color = document.getElementById("color");

 
var selected_cycles=  SelectedCycles().toString();
console.log(selected_cycles);

 
  color.innerHTML="<b><blink>Querying...("+ne.lat()+","+ne.lng()+") to ("+sw.lat()+","+sw.lng()+")</blink></b>";
  color.style.backgroundColor='white';


	if($('#committee').is(':checked') && 
		$('#candidate').is(':checked') && 
		$('#individual').is(':checked') && 
		$('#opinion').is(':checked') 
		|| 
		!$('#committee').is(':checked') && 
		!$('#candidate').is(':checked') && 
		!$('#individual').is(':checked') && 
		!$('#opinion').is(':checked')){
        // debug status flows through by cookie
        var query_string = "rwb.pl?act=near&latne="+ne.lat()+"&longne="+ne.lng()+"&latsw="+sw.lat()+"&longsw="+sw.lng();
        query_string = query_string + "&cycle=" + selected_cycles;document.getElementById("color")
        query_string = query_string + "&format=raw&what=all";
        console.log(query_string);
        $.get(query_string, NewData);

      }
      else{
        var what_string = "";
        var what_array = [];
//first push the value to the array then convert it to string
        if($('#committee').is(':checked')){
          what_array.push("committees");
        }
        if($('#candidate').is(':checked')){
          what_array.push("candidates");
        }
        if($('#individual').is(':checked')){
          what_array.push("individuals");
        }
        if($('#opinion').is(':checked')){
          what_array.push("opinions");
        }
        what_string = what_array.join(',');
        var query_string = "rwb.pl?act=near&latne="+ne.lat()+"&longne="+ne.lng()+"&latsw="+sw.lat()+"&longsw="+sw.lng();
        query_string += "&cycle=" + selected_cycles;
        query_string += "&format=raw&what=" + what_string;
        console.log(query_string);
console.log("fdgsdfg");
        $.get(query_string, NewData);
      }
}



function Reposition(pos)
{
    var lat=pos.coords.latitude;
    var long=pos.coords.longitude;

    map.setCenter(new google.maps.LatLng(lat,long));
    usermark.setPosition(new google.maps.LatLng(lat,long));
    document.cookie = 'Location=' + lat + '/' + long;
}


function Start(location) 
{
  var lat = location.coords.latitude;
  var long = location.coords.longitude;
  var acc = location.coords.accuracy;
  
  var mapc = $( "#map");

  map = new google.maps.Map(mapc[0], 
			    { zoom:16, 
				center:new google.maps.LatLng(lat,long),
				mapTypeId: google.maps.MapTypeId.HYBRID
				} );

  usermark = new google.maps.Marker({ map:map,
					    position: new google.maps.LatLng(lat,long),
					    title: "You are here"});
   document.cookie = 'Location=' + lat + '/' + long;

  markers = new Array;

  var color = document.getElementById("color");
  color.style.backgroundColor='white';
  color.innerHTML="<b><blink>Waiting for first position</blink></b>";

  google.maps.event.addListener(map,"bounds_changed",ViewShift);
  google.maps.event.addListener(map,"center_changed",ViewShift);
  google.maps.event.addListener(map,"zoom_changed",ViewShift);

  navigator.geolocation.watchPosition(Reposition);

}

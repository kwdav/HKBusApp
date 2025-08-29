<!DOCTYPE html>
<html>
<head>
    <?php $page_title = "搜索"; ?>
    <?php include('_inc_head.php'); ?>
    <script src="js/bus_time.js?<?php echo time();?>"></script>
</head>
<body class="search">
    <div class="top-fixed-bar grad"></div>
    <div class="wrapper">
        <div class="context">
            <h2>輸入巴士號碼</h2>
            <form id="busForm" class="search-form">
            <label for="route">Route Number:</label>
            <input type="text" id="route" name="route">
            <label for="direction">Direction:</label>
            <select id="direction" name="direction">
                <option value="outbound">Outbound</option>
                <option value="inbound">Inbound</option>
            </select>
            
            <label for="operator">Operator:</label>
            <select id="operator" name="operator">
                <option value="CTB">CTB</option>
                <option value="KMB">KMB</option>
                <option value="NWFB">NWFB</option>
            </select>
            
            <input type="submit" value="Get Bus Stops">
            </form>

            <h2>Bus Stops</h2>
            <ul id="busStops" class="bus-stop-list"></ul>
            </div>
    </div>
    <?php include('_inc_body_tab.php'); ?>




<script>
    $(document).ready(function() {
        $('#route').focus();
    });
    $('#busForm').on('submit', function(e) {
            e.preventDefault();
            
            $('#busStops').empty();

            var route = $('#route').val();
            var direction = $('#direction').val();
            var operator = $('#operator').val();
            
            var apiUrl = "";
            
            if(operator === "CTB") {
                apiUrl = "https://rt.data.gov.hk/v2/transport/citybus/route-stop/CTB/" + route + "/" + direction;
            } else if(operator === "KMB") {
                apiUrl = "https://data.etabus.gov.hk/v1/transport/kmb/route-stop/" + route + "/" + direction + "/1";
            } 

            //console.log(apiUrl);

            $.ajax({
                url: apiUrl,
                type: "GET",
                success: function(result) {
                    if(Array.isArray(result.data)) {
                        result.data.forEach(function(stop) {
                            // Get the bus stop name in traditional Chinese
                            var stopUrl = "";
                            if(operator === "CTB") {
                                stopUrl = "https://rt.data.gov.hk/v2/transport/citybus/stop/" + stop.stop;
                            } else if(operator === "KMB") {
                                stopUrl = "https://data.etabus.gov.hk/v1/transport/kmb/stop/" + stop.stop;
                            }
                            $.ajax({
                                url: stopUrl,
                                type: "GET",
                                success: function(stopResult) {                             
                                    $('#busStops').append(`<li><div class="bus-stop-order">${stop.seq}</div><div class="bus-stop-name">${stopResult.data.name_tc}</div><div class="bus-stop-id">${stop.stop}</li>`);
                                },
                                error: function(error) {
                                    console.log("Error:", error);
                                }
                            });
                        });
                        

                        
                        $('#busStops').on('click', 'li', function() {
                            //use the stop id and bus number to get the eta
                            var stopId = $(this).find('.bus-stop-id').text();
                            var busNumber = $('#route').val();
                            var etaUrl = "";
                            var $clickedItem = $(this);
                            if(operator === "CTB") {
                                etaUrl = "https://rt.data.gov.hk/v2/transport/citybus/eta/CTB/" + stopId + "/" + busNumber;
                            } else if(operator === "KMB") {
                                etaUrl = "https://data.etabus.gov.hk/v1/transport/kmb/eta/" + stopId + "/" + busNumber + "/1";
                            }

                            $.ajax({
                                url: etaUrl,
                                type: "GET",
                                success: function(etaResult) {
                                    $('#busStops li').removeClass('selected');
                                    $clickedItem.addClass('selected');
                                    $('#busStops li').find('.eta').remove();
                                    $clickedItem.append('<div class="eta"><ol></ol></div>');
                                    etaResult.data.forEach(function(eta) {
                                        //format the time to HH:MM
                                        var etaTime = eta.eta.substring(11, 16);
                                        //count the minutes left
                                        etaMinutes = calculateMinutesUntil(eta.eta);
                                        
                                        //append the eta to the clicked item in the list of div.eta
                                        //check the direction of the bus, and only show the eta of the same direction (Only check the inital lower character)
                                        etaDirection = eta.dir.substring(0, 1).toLowerCase();
                                        selectedDirection = $('#direction').val().substring(0, 1).toLowerCase();
                                        if(etaDirection === selectedDirection){
                                            $clickedItem.find('.eta ol').append(`<li>${etaMinutes}<span class="min">min</span><div class="time">(${etaTime})</div></li>`);
                                        }
                                        //add the class based on the order of li with "eta-1st", "eta-2nd", "eta-3rd"
                                        $clickedItem.find('.eta ol li').eq(0).addClass('eta-1st');
                                        $clickedItem.find('.eta ol li').eq(1).addClass('eta-2nd');
                                        $clickedItem.find('.eta ol li').eq(2).addClass('eta-3rd');

                                            


                                        console.log(etaUrl);
                                        
                                    });
                                    
                                },
                                error: function(error) {
                                    console.log("Error:", error);
                                }
                            });
                            

                            

                        });
                        

                        
                        
                        


                    } else {
                        console.log("Invalid response format");
                    }
                },
                error: function(error) {
                    console.log("Error:", error);
                }
            });
        });

</script>
</body>
</html>
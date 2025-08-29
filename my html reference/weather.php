<!DOCTYPE html>
<html>
<head>
    <?php $page_title = "天氣"; ?>
    <?php include('_inc_head.php'); ?>
</head>
<body class="weather">
    <div class="top-fixed-bar"></div>
    <div class="wrapper">
        <div class="context">
            <div id="general-weather" class="weather-info-card"></div>
            <script>
                $(document).ready(function() {
                    $.ajax({
                        url: `https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=flw&lang=tc`,
                        type: "GET",
                        dataType: "json",
                        success: function(data) {
                            console.log(data);
                            //format the date to be 2024年12月4日 (星期一) 12:00
                            var date = new Date(data.updateTime);
                            var year = date.getFullYear();
                            var month = date.getMonth() + 1;
                            var day = date.getDate();
                            var week = date.getDay();
                            var hour = date.getHours();
                            var minute = date.getMinutes();
                            var weekArray = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
                            var weekString = weekArray[week];
                            var updateTime = `${year}年${month}月${day}日 (${weekString}) ${hour}:${minute}`;
                            

                            
                            $('#general-weather').append(`<h2>${data.forecastPeriod}</h2>`);
                            $('#general-weather').append(`<div class="weather-update-date">${updateTime}</div>`);

                            $('#general-weather').append(`<p>${data.generalSituation}</p>`);

                            $('#general-weather').append(`<p>${data.forecastDesc}</p>`);
                            $('#general-weather').append(`<p>${data.outlook}</p>`);
                            
                            $('#general-weather').append(`<p>${data.tcInfo}</p>`);
                            $('#general-weather').append(`<p>${data.fireDangerWarning}</p>`);


                            

                        },
                        error: function(err) {
                            console.log(err);
                        }
                    });
                }, function(error) {
                    console.log(error);
                });
                    
            </script>
                        
            
            
            <h2>9天天氣預報</h2>
            <div id="weather"></div>
            <script>
                $(document).ready(function() {
                    $.ajax({
                        url: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=fnd&lang=tc",
                        type: "GET",
                        dataType: "json",
                        success: function(data) {
                            console.log(data);
                            var weather = data.weatherForecast;
                            var html = "";
                            for(var i = 0; i < weather.length; i++) {
                                html += `<div class="weather-item">
                                    <div class="weather-date">${weather[i].week}</div>
                                    <div class="weather-icon"><img src="https://www.hko.gov.hk/images/HKOWxIconOutline/pic${weather[i].ForecastIcon}.png"></div>
                                    <div class="weather-temp">${weather[i].forecastMintemp.value}°C - ${weather[i].forecastMaxtemp.value}°C</div>
                                    <div class="weather-rain">${weather[i].forecastMaxrh.value}%</div>
                                </div>`;
                            }
                            $('#weather').html(html);
                        },
                        error: function(err) {
                            console.log(err);
                        }
                    });
                });
            </script>
            
            


        </div>
    </div>
    <?php include('_inc_body_tab.php'); ?>

</body>
</html>

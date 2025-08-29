function calculateMinutesUntil(dateString) {
    let now = new Date();
    let arrivalTime = new Date(dateString);
    let differenceInMilliseconds = arrivalTime - now;
    let differenceInMinutes = Math.round(differenceInMilliseconds / 1000 / 60);
    return differenceInMinutes;
}

function formatEta(etaString) {
    if (etaString) {
        let minutesUntil = calculateMinutesUntil(etaString);
        let arrivalTime = new Date(etaString);
        let hours = arrivalTime.getHours().toString().padStart(2, '0');
        let minutes = arrivalTime.getMinutes().toString().padStart(2, '0');
        return `${minutesUntil}<span class="min">分鐘</span> <div class="time">(${hours}:${minutes})</div>`;
    } else {
        return '未有資料';
    }
}

//Example here for the requests array
/* 
let requests = [
    {stopId: '003472', route: '793', companyId: 'CTB', direction: 'outbound'},
    {stopId: '003472', route: '795X', companyId: 'CTB', direction: 'outbound'}
]
*/

// 創建緩存對象
var stopCache = {};

// Basic setup for the html. Create a div for each request in requests. And fill in the stop name and route number.
function listSetup(){
for (let request of requests) {

    let div = document.getElementById(`${request.companyId}_${request.stopId}_${request.route}_${request.direction}`);  // Get the existing div
    
    let etaUrl, stopUrl, routeUrl;
        if (request.companyId === 'KMB') {
            stopUrl = `https://data.etabus.gov.hk/v1/transport/kmb/stop/${request.stopId}`;
            routeUrl = `https://data.etabus.gov.hk/v1/transport/kmb/route/${request.route}/${request.direction}/1`;
            
        } else if (request.companyId === 'CTB') {
            stopUrl = `https://rt.data.gov.hk/v2/transport/citybus/stop/${request.stopId}`;
            routeUrl = `https://rt.data.gov.hk/v2/transport/citybus/route/${request.companyId}/${request.route}`;
        } else {
            console.log('Invalid companyId');
            continue;
        }

    // 發起 API 請求獲取目的地
    let routeDataRequest = $.ajax({url: routeUrl, type: 'GET', dataType: 'json'});
    routeDataRequest.then(function(routeData) {
        //因應路線的方向，決定orig_tc或dest_tc為目的地
        if (request.direction == 'inbound') {
            div.querySelector('.stop-dest').innerHTML = `返：${routeData.data.orig_tc}`;
        } else {
            div.querySelector('.stop-dest').innerHTML = `往：${routeData.data.dest_tc}`;
        }
    });

    // 檢查緩存是否已經有站名
    let stopName;
    if (stopCache[request.stopId]) {
        stopName = stopCache[request.stopId];
    } else {
        // 發起 API 請求獲取站名
        let stopDataRequest = $.ajax({url: stopUrl, type: 'GET', dataType: 'json'});
        stopDataRequest.then(function(stopData) {
            // 將站名存入緩存
            stopCache[request.stopId] = stopData.data.name_tc;
            // div中的站名
            div.querySelector('.stop-name').innerHTML = stopData.data.name_tc;
        });
    }


    div.innerHTML = `<div class='route-number'>${request.route}</div>
    <div class="route-stop">
        <div class='stop-name'>${stopName}</div>
        <div class='stop-dest'></div>
    </div>
    <div class="eta">
        <ol>

        </ol>
    </div>`


    }
}
    
    




    






function loadETA() {
    for (let request of requests) {
        // 透過 companyId, stopId, route 組合出 div 的 id
        let div = document.getElementById(`${request.companyId}_${request.stopId}_${request.route}_${request.direction}`);  // Get the existing div

        let etaUrl, stopUrl, routeUrl;
        if (request.companyId === 'KMB') {
            etaUrl = `https://data.etabus.gov.hk/v1/transport/kmb/eta/${request.stopId}/${request.route}/1`;
            stopUrl = `https://data.etabus.gov.hk/v1/transport/kmb/stop/${request.stopId}`;
            routeUrl = `https://data.etabus.gov.hk/v1/transport/kmb/route/${request.route}/${request.direction}/1`;
            
        } else if (request.companyId === 'CTB') {
            etaUrl = `https://rt.data.gov.hk/v2/transport/citybus/eta/${request.companyId}/${request.stopId}/${request.route}`;
            stopUrl = `https://rt.data.gov.hk/v2/transport/citybus/stop/${request.stopId}`;
            routeUrl = `https://rt.data.gov.hk/v2/transport/citybus/route/${request.companyId}/${request.route}`;
        } else {
            console.log('Invalid companyId');
            continue;
        }
        // 發起 API 請求獲取到站時間
        let busDataRequest = $.ajax({url: etaUrl, type: 'GET', dataType: 'json'});

        Promise.all([busDataRequest])
            .then(function([etaData]) {
                //get the first letter of the request's direction
                let busDirectionFirstLetter = request.direction.charAt(0);
                //change the character to be captial
                busDirectionFirstLetter = busDirectionFirstLetter.toUpperCase();
                //only keep the data that is in the same direction as the request
                let etaDataFiltered = etaData.data.filter(function(etaData) {
                    return etaData.dir == busDirectionFirstLetter;
                });

                div.querySelector('.eta').innerHTML = `<ol>
                                                            <li class="eta-1st">${etaDataFiltered[0] ? formatEta(etaDataFiltered[0].eta) : '未有資料'}</li>
                                                            <li class="eta-2nd">${etaDataFiltered[1] ? formatEta(etaDataFiltered[1].eta) : ''}</li>
                                                            <li class="eta-3rd">${etaDataFiltered[2] ? formatEta(etaDataFiltered[2].eta) : ''}</li>
                                                        </ol>`
            })
            .catch(function(error) {
                div.querySelector('.eta').innerHTML = `<ol>
                            <li class="eta-2nd">未有資料</li>
                        </ol>
                    `;
            });
       
        
    }
}

//inital setup for the page
$(document).ready(function() {
    listSetup();
    loadETA();
    setInterval(loadETA, 50000);

    var refreshButton = $('#refreshButton');
    
    refreshButton.on('click', function() {
        loadETA();
        refreshButton.prop('disabled', true); // 禁用按鈕
        refreshButton.html('⏳更新中...'); //更改按鈕文字
        setTimeout(function() {
            refreshButton.prop('disabled', false); // 啟用按鈕
            refreshButton.html('更新資料'); // 更改按鈕文字
        }, 5000); // 5秒後啟用按鈕
    });
});


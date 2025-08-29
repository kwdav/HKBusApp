<!DOCTYPE html>
<html>
<head>
    <? $page_title = "巴士到站時間"; ?>
    <? include('_inc_head.php'); ?>
    <script src="js/bus_time.js?<?php echo time();?>"></script>
    <!-- use php to generate the js and the html to replace the existing code -->
    <?php
        $busData = array(
            array('stopId' => '003472', 'route' => '793', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '由雍明苑出發'),
            array('stopId' => '003472', 'route' => '795X', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '由雍明苑出發'),
            array('stopId' => '003472', 'route' => '796X', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '由雍明苑出發'),
            array('stopId' => '003472', 'route' => '796P', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '由雍明苑出發'),
            array('stopId' => '001826', 'route' => '798', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '由雍明苑出發'),
            array('stopId' => '002917', 'route' => '793', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '到達調景嶺站'),
            array('stopId' => '002917', 'route' => '795X', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '到達調景嶺站'),
            array('stopId' => '002917', 'route' => '796X', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '到達調景嶺站'),
            array('stopId' => '002917', 'route' => '796P', 'companyId' => 'CTB', 'direction' => 'outbound', 'subTitle' => '到達調景嶺站'),
            array('stopId' => '002917', 'route' => '793', 'companyId' => 'CTB', 'direction' => 'inbound', 'subTitle' => '由調景嶺回家方向'),
            array('stopId' => '002917', 'route' => '796X', 'companyId' => 'CTB', 'direction' => 'inbound', 'subTitle' => '由調景嶺回家方向'),
            array('stopId' => '001764', 'route' => '795X', 'companyId' => 'CTB', 'direction' => 'inbound', 'subTitle' => '由調景嶺回家方向'),
            array('stopId' => '001764', 'route' => '796P', 'companyId' => 'CTB', 'direction' => 'inbound', 'subTitle' => '由調景嶺回家方向'),
            
            array('stopId' => 'A60AE774B09A5E44', 'route' => '40', 'companyId' => 'KMB', 'direction' => 'outbound', 'subTitle' => '其他')
        );
        echo '<script>';
        echo 'let requests = ' . json_encode($busData) . ';';
        echo '</script>';
    ?>
    

</head>
<body class="fav">
    <div class="top-fixed-bar"></div>
    <div class="wrapper">
        <div class="context">
            <div id="busData" class="busData">
                <!-- generate the html based on the busData -->
                <?php
                    $currentSubTitle = '';
                    foreach ($busData as $bus) {
                        if ($currentSubTitle !== $bus['subTitle']) {
                            $currentSubTitle = $bus['subTitle'];
                            echo '<div class="busDataSubTitle">' . $currentSubTitle . '</div>';
                        }
                        echo '<div id="' . $bus['companyId'] . '_' . $bus['stopId'] . '_' . $bus['route'] . '_' . $bus['direction'] . '" class="eta-item eta-' . $bus['companyId'] . '"></div>';
                    }
                ?>
            </div>
        </div>
    </div>

    
    


    
    <? include('_inc_body_tab.php'); ?>

</body>
</html>


<?php
require_once '../config.php';
header('Content-Type: application/json');

if (!isset($_GET['token'])) {
    echo json_encode([
        'status' => false,
        'message' => 'Missing Package Token',
        'force_exit' => true
    ]);
    exit;
}

$token = mysqli_real_escape_string($conn, $_GET['token']);
$checkProject = mysqli_query($conn, "SELECT id, contact_link, is_maintenance FROM tbl_projects WHERE project_token = '$token' LIMIT 1");

if (mysqli_num_rows($checkProject) == 0) {
    echo json_encode([
        'status' => false,
        'message' => 'Invalid Package Token',
        'force_exit' => true
    ]);
    exit;
}

$projectData = mysqli_fetch_assoc($checkProject);
$project_id = $projectData['id'];
$action = isset($_GET['action']) ? $_GET['action'] : '';

if ($action == 'init') {
    echo json_encode([
        'status' => true,
        'contact' => $projectData['contact_link'],
        'maintenance' => intval($projectData['is_maintenance'])
    ]);
    exit;
}

if ($action == 'check') {
    if (!isset($_GET['key']) || !isset($_GET['uuid'])) {
        echo json_encode(['status' => false, 'message' => 'Missing params']);
        exit;
    }

    $key = mysqli_real_escape_string($conn, $_GET['key']);
    $uuid = mysqli_real_escape_string($conn, $_GET['uuid']);
    $now = date('Y-m-d H:i:s');

    $query = mysqli_query($conn, "SELECT * FROM tbl_tokens WHERE token_code = '$key' AND project_id = $project_id LIMIT 1");
    
    if (mysqli_num_rows($query) == 0) {
        echo json_encode(['status' => false, 'message' => 'Key invalid for this package']);
        exit;
    }

    $data = mysqli_fetch_assoc($query);

    if ($projectData['is_maintenance'] == 1) {
        echo json_encode([
            'status' => false, 
            'message' => 'System Maintenance', 
            'contact' => $projectData['contact_link'],
            'force_exit' => true
        ]);
        exit;
    }

    if ($data['type'] == 'dynamic' && $data['expire_date'] == null) {
        $days = $data['duration'];
        $newExpire = date('Y-m-d H:i:s', strtotime("+$days days"));
        mysqli_query($conn, "UPDATE tbl_tokens SET expire_date = '$newExpire' WHERE id = " . $data['id']);
        $data['expire_date'] = $newExpire;
    }

    if ($data['expire_date'] < $now) {
        echo json_encode([
            'status' => false, 
            'message' => 'Key expired',
            'contact' => $projectData['contact_link']
        ]);
        exit;
    }

    $checkDevice = mysqli_query($conn, "SELECT * FROM tbl_device_history WHERE token_id = " . $data['id'] . " AND device_uuid = '$uuid'");
    if (mysqli_num_rows($checkDevice) == 0) {
        $countUsed = mysqli_num_rows(mysqli_query($conn, "SELECT * FROM tbl_device_history WHERE token_id = " . $data['id']));
        if ($countUsed >= $data['max_devices']) {
            echo json_encode([
                'status' => false, 
                'message' => 'Max devices reached',
                'contact' => $projectData['contact_link']
            ]);
            exit;
        }
        mysqli_query($conn, "INSERT INTO tbl_device_history (token_id, device_uuid) VALUES (" . $data['id'] . ", '$uuid')");
    }

    $remaining = strtotime($data['expire_date']) - strtotime($now);
    $daysLeft = floor($remaining / 86400);
    if ($daysLeft < 0) $daysLeft = 0;

    echo json_encode([
        'status' => true,
        'message' => 'Active',
        'expiry' => $data['expire_date'],
        'days_left' => $daysLeft,
        'contact' => $projectData['contact_link']
    ]);
    exit;
}

echo json_encode(['status' => false, 'message' => 'Unknown action']);
?>
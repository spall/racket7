
(define network-table
  (make-primitive-table
   tcp-abandon-port
   tcp-accept
   tcp-accept-evt
   tcp-accept-ready?
   tcp-accept/enable-break
   tcp-addresses
   tcp-close
   tcp-connect
   tcp-connect/enable-break
   tcp-listen
   tcp-listener?
   tcp-port?
   udp?
   udp-bind!
   udp-bound?
   udp-close
   udp-connect!
   udp-connected?
   udp-multicast-interface
   udp-multicast-join-group!
   udp-multicast-leave-group!
   udp-multicast-loopback?
   udp-multicast-set-interface!
   udp-multicast-set-loopback!
   udp-multicast-set-ttl!
   udp-multicast-ttl
   udp-open-socket
   udp-receive!
   udp-receive!*
   udp-receive!-evt
   udp-receive!/enable-break
   udp-receive-ready-evt
   udp-send
   udp-send*
   udp-send-evt
   udp-send-ready-evt
   udp-send-to
   udp-send-to*
   udp-send-to-evt
   udp-send-to/enable-break
   udp-send/enable-break))

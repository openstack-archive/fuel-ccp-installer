#!/bin/bash
test_networking() {
    SLAVE_IPS=${SLAVE_IPS:-changeme}
    ADMIN_IP=${ADMIN_IP:-changeme}

    #Uncomment and set if running manually
    #SLAVE_IPS=(10.10.0.2 10.10.0.3 10.10.0.3)
    #ADMIN_IP="10.90.2.4"

    if [[ "$SLAVE_IPS" == "changeme" || "$ADMIN_IP" == "changeme" ]];then
        SLAVE_IPS=($(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'))
        ADMIN_IP=${SLAVE_IPS[0]}
        if [ -z "$SLAVE_IPS" ]; then
            echo "Unable to determine k8s nodes. Please set variables SLAVE_IPS and ADMIN_IP."
            return 1
        fi
    fi

    ADMIN_USER="vagrant"
    SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownhostsFile=/dev/null"
    kubedns_ip=$(ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP kubectl get svc --namespace kube-system kubedns --template={{.spec.clusterIP}})
    dnsmasq_ip=$(ssh $SSH_OPTIONS $ADMIN_USER@$ADMIN_IP kubectl get svc --namespace kube-system dnsmasq --template={{.spec.clusterIP}})
    domain="cluster.local"

    internal_test_domain="kubernetes.default.svc.${domain}"
    external_test_domain="kubernetes.io"

    declare -A node_ip_works
    declare -A node_internal_dns_works
    declare -A node_external_dns_works
    declare -A container_dns_works
    declare -A container_hostnet_dns_works
    failures=0
    acceptable_failures=0
    for node in "${SLAVE_IPS[@]}"; do
        # Check UDP 53 for kubedns
        if ssh $SSH_OPTIONS $ADMIN_USER@$node nc -uzv $kubedns_ip 53 >/dev/null; then
            node_ip_works["${node}"]="PASSED"
        else
            node_ip_works["${node}"]="FAILED"
            (( failures++ ))
        fi
        # Check internal lookup
        if ssh $SSH_OPTIONS $ADMIN_USER@$node nslookup $internal_test_domain $kubedns_ip >/dev/null; then
            node_internal_dns_works["${node}"]="PASSED"
        else
            node_internal_dns_works["${node}"]="FAILED"
            (( failures++ ))
        fi

        # Check external lookup
        if ssh $SSH_OPTIONS $ADMIN_USER@$node nslookup $external_test_domain $dnsmasq_ip >/dev/null; then
            node_external_dns_works[$node]="PASSED"
        else
            node_external_dns_works[$node]="FAILED"
            (( failures++ ))
        fi

        # Check UDP 53 for kubedns in container
        if ssh $SSH_OPTIONS $ADMIN_USER@$node sudo docker run --rm busybox nslookup $external_test_domain $dnsmasq_ip >/dev/null; then
            container_dns_works[$node]="PASSED"
        else
            container_dns_works[$node]="FAILED"
            (( failures++ ))
        fi
        # Check UDP 53 for kubedns in container with host networking
        if ssh $SSH_OPTIONS $ADMIN_USER@$node sudo docker run --net=host --rm busybox nslookup $external_test_domain $dnsmasq_ip >/dev/null; then
            container_hostnet_dns_works[$node]="PASSED"
        else
            container_hostnet_dns_works[$node]="FAILED"
            (( failures++ ))
        fi
    done

    # Report results
    echo "Found $failures failures."
    for node in "${SLAVE_IPS[@]}"; do
        echo
        echo "Node $node status:"
        echo "  Node to container communication: ${node_ip_works[$node]}"
        echo "  Node internal DNS lookup (via kubedns): ${node_internal_dns_works[$node]}"
        echo "  Node external DNS lookup (via dnsmasq): ${node_external_dns_works[$node]}"
        echo "  Container internal DNS lookup (via kubedns): ${container_dns_works[$node]}"
        echo "  Container internal DNS lookup (via kubedns): ${container_hostnet_dns_works[$node]}"
    done
    if [[ $failures > $acceptable_failures ]]; then
      return $failures
    else
      return 0
    fi
}

#Run test_networking if not sourced
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || test_networking $@


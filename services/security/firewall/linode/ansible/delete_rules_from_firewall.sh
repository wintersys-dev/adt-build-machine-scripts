---
- name: Clear All Rules From A Specific Linode Firewall
  hosts: localhost
  gather_facts: false
  vars:
    # Set your Linode API Token as an environment variable (export LINODE_API_TOKEN="your_token")
    linode_api_token: "{{ lookup('ansible.builtin.env', 'LINODE_API_TOKEN') }}"
    
    # Enter the exact numeric ID of the specific firewall you want to wipe clean
    target_firewall_id: 123456  

    # Choose default behavior once rules are gone: ACCEPT or DROP
    default_inbound_policy: "DENY"  
    default_outbound_policy: "ACCEPT" 

  tasks:
    - name: Ensure Linode API token is available
      ansible.builtin.fail:
        msg: "Please set the LINODE_API_TOKEN environment variable before running this playbook."
      when: linode_api_token | length == 0

    - name: Purge all inbound and outbound rules regardless of content
      ansible.builtin.uri:
        url: "https://linode.com{{ target_firewall_id }}/rules"
        method: PUT
        headers:
          Authorization: "Bearer {{ linode_api_token }}"
          Content-Type: "application/json"
        body_format: json
        body:
          inbound: []
          outbound: []
          inbound_policy: "{{ default_inbound_policy }}"
          outbound_policy: "{{ default_outbound_policy }}"
        status_code: 200
      register: api_response

    - name: Confirm successful removal
      ansible.builtin.debug:
        msg: "Successfully cleared all rules from Firewall ID {{ target_firewall_id }}."

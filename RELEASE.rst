Fuel CCP Installer release process
----------------------------------

In order to tag a release of MCP Installer, the following items must be set:
* Pinned Fuel-devops version
* Pinned Kargo commit
* Pinned Docker version
* Pinned Calico version
* Pinned Kubernetes hyperkube image
* Pinned etcd version
* Minimum Ansible version

List of items to check off before tagging release:
* CI passes (pep8, pytest, docs, and functional test)
* HA destructive test:
  * disable first master, restart kubelet on all nodes, check kubectl get nodes,
    restart first master, check kubectl get nodes
* QA signoff
* fuel-devops version 
* test coverage is green
* CCP team signoff
* Fuel-ccp deployment succeeds and contains no blocker bugs

Estimated timeline: 3 days to propose release and obtain signoff.

Technical Details
^^^^^^^^^^^^^^^^^

Master branch of fuel-ccp-installer will principally point to “master” commit
of Kargo, except during release time.

Release manager will create a commit to fuel-ccp-installer, pinning
KARGO_COMMIT to either a tagged release of Kargo or a specific commit.

After all signoffs are obtained, the commit will be merged.

Release manager will create a tag in Gerrit for the new release.

Release manager creates another commit to un-pin KARGO_COMMIT back to “master”
gitref.

# Preflight Agent

This chart is designed to be installed as a dependency of the `jetstacksecure-mp` chart.

It may eventually be moved to the [public Preflight Agent Repository](https://github.com/jetstack/preflight).

For testing purposes, you can install the Preflight agent using Helm, as follows:

```
helm install \
    --create-namespace \
    --namespace jetstack-secure \
    --set serviceAccount.create=true \
    --set rbac.create=true \
    jetstack-secure \
    chart/preflight 
```

Next you will need to register the agent.
For example, to configure the agent for "Machine Identity / Cert Inventory", please follow these steps:

1. Visit https://platform.jetstack.io/
2. Click the "Machine Identity" button, in the tool bar on the left
3. Click "ADD CLUSTER"
4. Follow the instructions
5. Click "COPY COMMAND TO CLIPBOARD" to copy the credentials and configuration command to the clipboard
6. Paste, inspect and then execute the command in your terminal

[**[Return To Main]**]

# FAQ

### Does the user have to develop the 3 elements of the provider (AEF, AMF and APF)?
No, you only have to make the request to the "/onboarding" endpoint. In it you must specify a CSR for the AEF, APF and AMF and you will receive the certificates for each of them in the response.

### There is one party that publishes the API and another that exposes it, what is the difference?
There are different services, the APF, intended for publishing the APIs, and the AEF, intended so that the invoker can call it. The APF is what connects to the Capif Core Function to publish the service and when the service is up, you need the AEF service so that invokers can connect to it.


### Before publishing an API, do you have to be registered in CAPIF?
Yes, before publishing an API you must register using the POST /register endpoint.


### Where is the registration done?
Registration is done in a REST API outside of the CAPIF specification taht we have implemented.


### Is the username and password chosen by the user when registering or is it assigned when requesting registration to CAPIF public instance?
When you make the request to the "/endpoint" of register, you will be returned a username and a password determined by CAPIF.


### What is a CSR?
A CSR is a Certificate Signing Request. It is a generated data block where the certificate is planned to be installed and contains key information such as public key, organization, and location, and is used to request a certificate from a certificate authority (CA). In CAPIF, 3 CSRs are necessary to register a provider, for AEF, APF and AMF.


### When doing the register_provider where can I find the CSRs that are generated?
When using the "register_provider" command, if you add the "debug" option, it shows you a json with the data used to register the provider. There we can find in the body a list of 3 elements corresponding to AEF, APF and AMF. IN each of them, the apiProbPubKey field corresponds to the CSR.


### How to use the example client (CAPIF_INVOKER_GUI)?
First you have to make a "./run.sh host:port" indicating the address of the public CAPIF. Once the Docker containers are up, you have to do a "./terminal_to_py_netapp.sh" and then a "python main.py". At this point we will find ourselves in a console with some predefined commands to use the Client. If we press tab twice it will bring up the list of available commands.


### Where is the CAPIF public instance located?
The CAPIF public instance can be found at the following URLs:
- capif.mobilesandbox.cloud:37211 (HTTPS)
- capif.mobilesandbox.cloud:37212 (HTTP)


### Do you have to publish 3 APIs? one for each instance?
No, you only have to publish a single API but each component is responsible for a specific service, whether publishing or exposing.


### Once the API is published, is it always active? Or do you have to republish it every time you want to use it?
It is better to unsubscribe the API every time you exit the application since otherwise it could be republished and it would be double.


### Would the same username and password be valid for different invokers?
Yes, a user can have multiple invokers at the same time, and as such, the username and password would be the same.


### What is the notfication destination field in the register_invoker request?
This is the callback URL used to notify events. CAPIF has an Event service to subscribe to that notifies actions such as a subscription to an API, a change in the state of an API...


### Is the notification_destination a required field in the register_invoker
No, it is not mandatory, but if you do not enter it you will not receive any CAPIF events. For example, the APF may delete the API, you will not be notified that the API is no longer available.


### What is the purpose of the "discover_service" function in the invoker client?
The discover_service returns a json with all the services that exist exposed in CAPIF at that moment.


### What is the purpose of the "get_security_auth" function in the invoker client?
Sirve para pedir el token o para refrescarlo en caso de que haya caducado. You have to use that token to call the API from the invoker.


### What is the purpose of the "register_security_context" function in the invoker client?
To consume the API it is necessary to have a Security Context registered with the data and the authentication method.


### Is a user the same as an exposer?
No, a user registers in CAPIF and once done can have the role of invoker, provider or both.


### Where can I put my endpoint?
You have to set your endpoint when doing the "publish_service" functionality:  
    ```
    publish_service capif_ops/config_files/service_api_description_hello.json
    ```

In the file "service_api_description_hello.json" you configure the service that is going to be exposed and by developing one to suit you, you expose your API.



 [Return To Main]: ./README.md#faq-documentation
Changes the variable values as you preffered requirement in variable.tfvars
 - Access_key  = Set your account access key
 - Secret_key = Set your account secret key 
 - region_name = set the your preffered region where you want to build infrastructure
 - instance_ami  = This code is depends on Ubuntu so select the ubuntu ami 
 - server_instance = Select the instance configuration type on your requirement
 - vpc_cidrblock = Set the network range 
 - subnet_cidrblock = Set the subnet ranges

IN user_data.sh
 - in line 26 set the ServerAdmin 

In main.tf 
 In the resource "aws_lb_listener" "https_listener"
 - ssl_policy: Choose an appropriate SSL policy that aligns with your security requirements. The example uses "ELBSecurityPolicy-2016-08" as a placeholder, but you should select the SSL policy that suits your needs best. AWS provides several predefined security policies that you can choose from.

 - certificate_arn: Replace "your-certificate-arn" with the actual ARN of the SSL/TLS certificate that you've either imported into AWS Certificate Manager (ACM) or obtained from a certificate authority.

 - Make sure that the specified SSL certificate ARN corresponds to the certificate you want to use for HTTPS traffic on your load balancer in the specified AWS region (ap-south-1 in this case). Adjust these values according to your specific certificate and security policy requirements.
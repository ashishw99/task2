Task-2 Automating Services With Terraform-II

This is the first task given by Vimal Daga sir under Hybrid Multi Cloud Training of creating a complete automated architecture consisting of AWS Instances, AWS Storage(EBS and S3) through terraform. Architecture:

![Untitled Diagram(6)](https://user-images.githubusercontent.com/48363834/87753477-55aaff80-c820-11ea-8c2c-12953119274d.png)

## Task Description:
1. Create Security group which allow the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the existing key or provided key and security group which we have created in step 1.
4. Launch one Volume using the EFS service and attach it in your vpc, then mount that volume into /var/www/html
5. Developer have uploded the code into github repo also the repo has some images.
6. Copy the github repo code into /var/www/html
7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

Before creating infrastructure let's see **_Some Basic Terraform Commands_**
- To initialize or install plugins:
> terraform init

- To check the code:
> terraform validate

- To run or deploy:
> terraform apply

- To destroy the complete infrastructure:
> terraform destroy


To create this setup:
First we have to write providers- here AWS
```
provider "aws" {
  region     = "ap-south-1"
  profile    = "mansi"
}
```

## Security Group:

Creating Security Group to allow port no. 80 for httpd, 22 for ssh and 2049 for NFS:

```
resource "aws_security_group" "nfssg" {
  name        = "nfssg"
  vpc_id     = "vpc-9de0fdf5"
  ingress {
    protocol   = "tcp"
    from_port  = 2049
    to_port    = 2049
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  
  }
}

```

![p1](https://user-images.githubusercontent.com/48363834/87754258-209fac80-c822-11ea-8230-c7267a9aa9c2.PNG)

## Instance:

Now, we can launch an instance named “taskinstance” and setting up ssh connection to ec2-user of newly launched instance.
Then, by using remote-exec installing git,httpd,php and amazon nfs utils and also starting service of httpd.
```
resource "aws_instance" "taskinstance" {
  depends_on = [ aws_security_group.nfssg,
		]

  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task2Key"
  security_groups = [ "nfssg" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("E:/DOWNLOADS/task2Key.pem")
    host     = aws_instance.taskinstance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo yum install amazon-efs-utils -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      
    ]
  }

  tags = {
    Name = "taskos"
  }

}

```
![p3](https://user-images.githubusercontent.com/48363834/87755032-d15a7b80-c823-11ea-8bd2-95d5572dca06.PNG)

## EFS Volume:


Creating an efs volume in the default VPC and same security group as of instance. And then attach it to ec2 instance .
```
resource "aws_efs_file_system" "taskvol" {
  depends_on = [
    aws_instance.taskinstance
  ]
  creation_token = "volume"

  tags = {
    Name = "MyEFS"
  }
}

resource "aws_efs_mount_target" "alpha" {
  depends_on =  [
                aws_efs_file_system.taskvol
  ] 
  file_system_id = "${aws_efs_file_system.taskvol.id}"
  subnet_id      = aws_instance.taskinstance.subnet_id
  security_groups = [ aws_security_group.nfssg.id ]
}

```
![p4](https://user-images.githubusercontent.com/48363834/87755850-68740300-c825-11ea-9f6f-0335be8ce336.PNG)

## S3 Bucket:


Now, We create a S3 bucket to store our files permanently.After creating bucket we have to place images in this so we will clone github repo in a folder at local system and then upload it.To upload object in S3 bucket we have to first add some permissions and then we can upload objects.

```
resource "aws_s3_bucket" "taskbucket" {
  bucket = "mybucket222455"
  acl    = "public-read"
 
  versioning {
    enabled = true
  }

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}



resource "null_resource" "localcopy"  {

	provisioner "local-exec" {
                     command = "git clone https://github.com/mansi-dadheech/hybrid_task1_image.git  E:/terraformWorkspace/task2/photos"
	    
  	}
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = "${aws_s3_bucket.taskbucket.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::mybucket222455/*"
      }
  ]
}
POLICY
}

```
To upload object:
```
resource "aws_s3_bucket_object" "object" {
  bucket = "mybucket222455"
  key    = "terraform.png"
  source = "E:/terraformWorkspace/task2/photos/terraform.png"
  content_type = "image/png"
  acl = "public-read"
  content_disposition = "inline"
  content_encoding = "base64"
  
}
```
Bucket created,object uploaded, policies and permission applied:
![p5](https://user-images.githubusercontent.com/48363834/87756301-4dee5980-c826-11ea-8c77-a894b86ee9f5.PNG)

## CloudFront Distribution:
Creating Cloud Front distributions and adding cache behaviours,restrictions and some policies.
```
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.taskbucket.bucket_regional_domain_name}"
    origin_id   = "S3-mybucket222455"
}

  enabled             = true
  default_root_object = "terraform.png"

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-mybucket222455"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
     }
  }
  tags = {
    Environment = "production"
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "task 1"
}

```
On applying:
![p6](https://user-images.githubusercontent.com/48363834/87757445-47f97800-c828-11ea-998d-795f33bb7090.PNG)

We can update image url in index.html file in instance manually.
And then finally displaying webpage using instance ip
```
resource "null_resource" "local"  {

depends_on = [
       aws_cloudfront_distribution.s3_distribution
   
  ]

	provisioner "local-exec" {
	    
            command = "start firefox  ${aws_instance.taskinstance.public_ip}"
  	}
}
```
Here is our webpage:
![p2](https://user-images.githubusercontent.com/48363834/87758032-54320500-c829-11ea-9360-bc20f4c22bd1.PNG)

I would like to thank *_Vimal Daga sir_* for giving this task. I got to know lots of concepts about terraform by this task.
*Thank You!!*










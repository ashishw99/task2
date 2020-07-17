provider "aws" {
  region     = "ap-south-1"
  profile    = "mansi"
}

// --------creating Security Group------------


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

// ------------Instance----------

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


//  -------------EFS volume---------------
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





resource "null_resource" "sshConnect"  {

depends_on = [
    aws_efs_mount_target.alpha
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("E:/DOWNLOADS/task2Key.pem")
    host     = aws_instance.taskinstance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mount -t efs '${aws_efs_file_system.taskvol.id}':/ /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/mansi-dadheech/hybrid_task1.git /var/www/html/"
    ]
  }
}

// ----------S3 Bucket -----------------

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
resource "aws_s3_bucket_object" "object" {
  bucket = "mybucket222455"
  key    = "terraform.png"
  source = "E:/terraformWorkspace/task2/photos/terraform.png"
  content_type = "image/png"
  acl = "public-read"
  content_disposition = "inline"
  content_encoding = "base64"
  
}

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


resource "null_resource" "local"  {

depends_on = [
       aws_cloudfront_distribution.s3_distribution
   
  ]

	provisioner "local-exec" {
	    
            command = "start firefox  ${aws_instance.taskinstance.public_ip}"
  	}
}




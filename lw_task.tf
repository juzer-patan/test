provider "aws"{
	region = "ap-south-1"
	profile = "juzer"

}

resource "tls_private_key" "test" {
  algorithm   = "RSA"
 
}
output "myop_tlskey"{
	value= tls_private_key.test 
}

resource "local_file" "web" {
    content     = tls_private_key.test.public_key_openssh
    filename = "mykey2233.pem"
    file_permission = 0400
}
 
//Create new aws key_pair

resource "aws_key_pair" "test_key" {
  key_name   = "mykey"
  public_key = tls_private_key.test.public_key_openssh

}


output "myop_key"{
	value= aws_key_pair.test_key

}

//Create new security_group allowing HTTP SSH

resource "aws_security_group" "terra_s" {
  name        = "myfirewall"
  description = "Allow HTTP SSH inbound traffic"
  vpc_id      = "vpc-5de8f535"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tcp"
  }
}

output "mysec"{
	value = aws_security_group.terra_s
}

//Clone image from github into local system

resource "null_resource" "local1" {
  	 provisioner "local-exec" {
    command = "git clone https://github.com/juzer-patan/terra_img.git C:/Users/juzer/Desktop/gitjpg"
  }
}

//Create S3 bucket

resource "aws_s3_bucket" "terrab" {
  bucket = "juzzybuck33"
  acl = "public-read"
  
}

//Give public access to S3 bucket

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = "${aws_s3_bucket.terrab.id}"

  
}

//Upload image downloaded from gihub repo to S3 bucket

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.terrab.id
  key    = "jpatan.jpg"
  source = "C:/Users/juzer/Desktop/gitjpg/jpatan.jpg"
  content_type = "image/jpeg"
  acl = "public-read"
}
//Create CloudFront OAI for S3 bucket

resource "aws_cloudfront_origin_access_identity" "cloud" {
  
}

locals {
  s3_origin_id = "S3-juzzybuck33"
}

//Create CloudFront distribution with S3 bucket as origin

resource "aws_cloudfront_distribution" "s3_distribution" {
	
  origin {
    domain_name = "${aws_s3_bucket.terrab.bucket_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cloud.cloudfront_access_identity_path
    }
  }

  enabled             = true



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  

  restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
output "myop_cf"{
	value= aws_cloudfront_distribution.s3_distribution.domain_name 

}

//Launch ec2 instance and remotely execute script to setup webserver

resource "aws_instance" "myin" {
	ami           = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	key_name = aws_key_pair.test_key.key_name
	security_groups = ["${aws_security_group.terra_s.name}"]


	tags = {
		Name = "TaskOs"
  }
	connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.test.private_key_pem
    host     = aws_instance.myin.public_ip
  }
	provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"	
    ]
  }
}

//Create new ebs volume

resource "aws_ebs_volume" "ebs2" {
  
	
  availability_zone = aws_instance.myin.availability_zone
  size              = 1

  tags = {
    Name = "Taskvol"
  }
}

//Attach volume to ec2 instance

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ebs2.id
  instance_id = aws_instance.myin.id
  force_detach = true
}
output "myaz"{
	value = aws_instance.myin.availability_zone
}
output "myebsid"{
	value = aws_ebs_volume.ebs2.id
}
output "myin_id"{
	value = aws_instance.myin.id
}

//Remotely execute script to format and mount attached ebs volume and clone github code to remote system

resource "null_resource" "local2" {
	depends_on = [
    aws_volume_attachment.ebs_att,
  ]
	connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.test.private_key_pem
    host     = aws_instance.myin.public_ip
  }
	provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdf",
      "sudo mount /dev/xvdf /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/juzer-patan/terra_iiec.git /var/www/html/"	
    ]
  }


    }

resource "null_resource" "local3" {
	depends_on = [
    null_resource.local2,
  ]
	 provisioner "local-exec" {
    command = "echo chrome ${aws_instance.myin.public_ip}"
  }
}

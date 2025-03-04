provider "aws" {
  region = "us-east-1"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com" # outra opção "https://ifconfig.me"
}

resource "aws_instance" "k8s_proxy" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  key_name      = "Itau_treinamento"
  tags = {
    Name = "k8s-haproxy"
  }
  vpc_security_group_ids = ["${aws_security_group.acessos.id}"]
}

resource "aws_instance" "k8s_masters" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.medium"
  key_name      = "Itau_treinamento"
  count         = 3
  tags = {
    Name = "k8s-master-${count.index}"
  }
  vpc_security_group_ids = ["${aws_security_group.acessos_master.id}"]
  depends_on = [
    aws_instance.k8s_workers,
  ]
}

resource "aws_instance" "k8s_workers" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  key_name      = "Itau_treinamento"
  count         = 3
  tags = {
    Name = "k8s_workers-${count.index}"
  }
  vpc_security_group_ids = ["${aws_security_group.acessos.id}"]
}


resource "aws_security_group" "acessos_master" {
  name        = "k8s-acessos_master"
  description = "acessos inbound traffic"

  ingress = [
    {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["${chomp(data.http.myip.body)}/32"]
      ipv6_cidr_blocks = []
      prefix_list_ids = null,
      security_groups: null,
      self: null
    },
    {
      cidr_blocks      = [
        "${var.ip_haproxy}/32",
      ]
      description      = "Libera haproxy"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
    {
      cidr_blocks      = []
      description      = "Libera acesso k8s_masters"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = true
      to_port          = 0
    },
    {
      cidr_blocks      = []
      description      = "Libera acesso k8s_workers"
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = [
        "sg-056665ffa54f46217",
      ]
      self             = false
      to_port          = 0
    },
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = [],
      prefix_list_ids = null,
      security_groups: null,
      self: null,
      description: "Libera dados da rede interna"
    }
  ]

  tags = {
    Name = "allow_ssh"
  }
}


resource "aws_security_group" "acessos" {
  name        = "k8s-acessos"
  description = "acessos inbound traffic"

  ingress = [
    {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["${chomp(data.http.myip.body)}/32"]
      ipv6_cidr_blocks = []
      prefix_list_ids = null,
      security_groups: null,
      self: null
    },
    {
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = [
        "${aws_security_group.acessos_master.id}",
      ]
      self             = false
      to_port          = 0
    },
    {
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = [
        "sg-05152ffdef1105622", # acesso para o proprio grupo pois os workers precisam acessar o haproxy
      ]
      self             = true
      to_port          = 0
    },
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = [],
      prefix_list_ids = null,
      security_groups: null,
      self: null,
      description: "Libera dados da rede interna"
    }
  ]

  tags = {
    Name = "allow_ssh"
  }
}


output "k8s-masters" {
  value = [
    for key, item in aws_instance.k8s_masters :
      "k8s-master ${key+1} - ${item.private_ip} - ssh -i ~/projetos/devops/id_rsa_itau_treinamento ubuntu@${item.public_dns}"
  ]
}


output "output-k8s_workers" {
  value = [
    for key, item in aws_instance.k8s_workers :
      "k8s-workers ${key+1} - ${item.private_ip} - ssh -i ~/projetos/devops/id_rsa_itau_treinamento ubuntu@${item.public_dns}"
  ]
}

output "output-k8s_proxy" {
  value = [
    "k8s_proxy - ${aws_instance.k8s_proxy.private_ip} - ssh -i ~/projetos/devops/id_rsa_itau_treinamento ubuntu@${aws_instance.k8s_proxy.public_dns}"
  ]
}

# terraform refresh para mostrar o ssh

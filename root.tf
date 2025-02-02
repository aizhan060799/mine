module "eks" {
  source           = "./eks-cluster"
  eks_cluster_name = "my-eks"
  vpc_id           = "vpc-0219589ed356be37e"
  public_subnets   = ["subnet-0143abb1a4ce6bd0e", "subnet-0b3d1adc9371f8244", "subnet-0f71b910b4b72bc58"]

  #private_subnets         = 
  instance_types = ["t2.medium", "t3.medium"]
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.7.1"

  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    file("./eks-cluster/values/nginx-ingress.yaml")
  ]

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = "arn:aws:iam::975050202573:user/admin"
        username = "admin"
        groups   = ["system:masters"]
      },
      {
        rolearn  = "arn:aws:iam::975050202573:role/project"
        username = "github-runner-cicd"
        groups   = ["system:masters"]
      },
      {
        rolearn  = "arn:aws:iam::975050202573:user/admin"
        username = "github-runner-terraform"
        groups   = ["system:masters"]
      },
      {
        rolearn  = module.eks.worker_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
    ])
    mapUsers = ""
  }

  depends_on = [
    module.eks,
  ]
}
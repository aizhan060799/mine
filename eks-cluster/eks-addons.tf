
# Fetch available versions for each add-on
data "aws_eks_addon_version" "eks_addons_version" {
  for_each = var.cluster_addons

  addon_name         = each.key
  kubernetes_version = var.k8s_version
}

# Create each add-on resource
resource "aws_eks_addon" "eks_addons" {
  for_each = var.cluster_addons

  cluster_name                = var.eks_cluster_name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.eks_addons_version[each.key].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
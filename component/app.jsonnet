local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.paralus;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('paralus', params.namespace);

{
  paralus: app,
}

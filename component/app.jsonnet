local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.paralus;
local argocd = import 'lib/argocd.libjsonnet';
local instance = inv.parameters._instance;

local appName = if instance == 'paralus' then 'paralus' else instance;
local app = argocd.App(appName, params.namespace);

{
  [instance]: app,
}

import { Construct } from 'constructs'
import { App, TerraformStack, TerraformOutput } from 'cdktf'
import { AwsProvider } from './.gen/providers/aws'
import ec2 = require('@aws-cdk/aws-ec2');
import eks = require('@aws-cdk/aws-eks');



class EKSStack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id)

    new AwsProvider(this, 'aws', {
      region: 'us-east-1',
    })


    const vpc = new ec2.Vpc(this, "eks-vpc");
    const eksCluster = new eks.Cluster(this, "Cluster", {
      vpc: vpc,
      kubectlEnabled: true,
      defaultCapacity: 0, // we want to manage capacity ourselves
      version: eks.KubernetesVersion.V1_18,
    });

    new TerraformOutput(this, 'cluster_arn', {
      value: eksCluster.clusterArn,
    })
  }
}

const app = new App()
new EKSStack(app, 'express-eks-stack')
app.synth()
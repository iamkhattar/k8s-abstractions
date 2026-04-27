package main

import (
	appsv1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/apps/v1"
	corev1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/core/v1"
	metav1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/meta/v1"
	networkingv1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/networking/v1"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		cfg := config.New(ctx, "")
		name := cfg.Get("name")
		if name == "" {
			name = "my-app"
		}
		image := cfg.Get("image")
		if image == "" {
			image = "nginx"
		}
		replicas := cfg.GetInt("replicas")
		if replicas == 0 {
			replicas = 2
		}

		labels := pulumi.StringMap{"app": pulumi.String(name)}

		deployment, err := appsv1.NewDeployment(ctx, name, &appsv1.DeploymentArgs{
			Metadata: &metav1.ObjectMetaArgs{
				Name: pulumi.String(name),
			},
			Spec: &appsv1.DeploymentSpecArgs{
				Replicas: pulumi.Int(replicas),
				Selector: &metav1.LabelSelectorArgs{
					MatchLabels: labels,
				},
				Template: &corev1.PodTemplateSpecArgs{
					Metadata: &metav1.ObjectMetaArgs{
						Labels: labels,
					},
					Spec: &corev1.PodSpecArgs{
						Containers: corev1.ContainerArray{
							&corev1.ContainerArgs{
								Name:  pulumi.String(name),
								Image: pulumi.String(image),
								Ports: corev1.ContainerPortArray{
									&corev1.ContainerPortArgs{
										ContainerPort: pulumi.Int(80),
									},
								},
							},
						},
					},
				},
			},
		})
		if err != nil {
			return err
		}

		svc, err := corev1.NewService(ctx, name+"-svc", &corev1.ServiceArgs{
			Metadata: &metav1.ObjectMetaArgs{
				Name: pulumi.String(name + "-svc"),
			},
			Spec: &corev1.ServiceSpecArgs{
				Selector: labels,
				Ports: corev1.ServicePortArray{
					&corev1.ServicePortArgs{
						Port:       pulumi.Int(80),
						TargetPort: pulumi.Int(80),
						Protocol:   pulumi.String("TCP"),
					},
				},
			},
		}, pulumi.DependsOn([]pulumi.Resource{deployment}))
		if err != nil {
			return err
		}

		ingressClassName := pulumi.String("traefik")

		_, err = networkingv1.NewIngress(ctx, name+"-ingress", &networkingv1.IngressArgs{
			Metadata: &metav1.ObjectMetaArgs{
				Name: pulumi.String(name + "-ingress"),
			},
			Spec: &networkingv1.IngressSpecArgs{
				// Use ingressClassName field, not the annotation
				IngressClassName: ingressClassName,
				Rules: networkingv1.IngressRuleArray{
					&networkingv1.IngressRuleArgs{
						Host: pulumi.String(name + ".shivlab.com"),
						Http: &networkingv1.HTTPIngressRuleValueArgs{
							Paths: networkingv1.HTTPIngressPathArray{
								&networkingv1.HTTPIngressPathArgs{
									Path:     pulumi.String("/"),
									PathType: pulumi.String("Prefix"),
									Backend: &networkingv1.IngressBackendArgs{
										Service: &networkingv1.IngressServiceBackendArgs{
											Name: svc.Metadata.Name().Elem(),
											Port: &networkingv1.ServiceBackendPortArgs{
												Number: pulumi.Int(80),
											},
										},
									},
								},
							},
						},
					},
				},
			},
		}, pulumi.DependsOn([]pulumi.Resource{svc}))
		if err != nil {
			return err
		}

		ctx.Export("url", pulumi.String("http://"+name+".shivlab.com"))
		return nil
	})
}

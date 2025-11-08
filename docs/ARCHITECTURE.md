# Architecture Guide

This document explains how we built the Terraform orchestration framework and why we made certain design decisions.

## The Big Picture

We needed a way to deploy the same infrastructure patterns across multiple AWS accounts without losing our minds. Here's what we came up with:

```
Internet → ALB (Public Subnet) → EC2 Instances (Private Subnet)
```

Simple, right? But the magic happens in how we orchestrate this across environments.

## Why This Architecture?

**Multi-Account Setup**: We use separate AWS accounts for dev, staging, and production. This isn't just for security (though that's important) - it also prevents someone from accidentally nuking production while testing something in dev.

**Centralized State**: All Terraform state lives in a shared services account. This means we don't lose track of what we've deployed, and multiple people can work on the same infrastructure without stepping on each other.

**Cross-Account Roles**: Instead of managing credentials for every account, we use AWS Organizations to assume roles. Much cleaner and more secure.

## Component Breakdown

### Application Load Balancers

We create ALBs in public subnets to handle incoming traffic. Nothing fancy here - just standard AWS load balancing.

**Health Checks**: We hit `/health` on each instance every 30 seconds. If an instance doesn't respond with HTTP 200, we stop sending traffic to it.

**SSL/TLS**: You can enable HTTPS, but we leave it optional since not everyone needs it in dev environments.

### EC2 Instances

**Web Servers**: These sit behind the ALB and serve your application. We include both Linux and Windows examples because, well, the world isn't all Linux.

**App Servers**: These don't get ALB traffic - they're for background processing or internal services.

**Instance Sizing**: We start small in dev (t3.small) and scale up for production. You can adjust this based on your needs.

## Network Design

### VPC Strategy

We assume you already have VPCs set up. This framework doesn't create networking infrastructure - it uses what you've got. Why? Because networking is usually handled by a different team, and we didn't want to step on their toes.

### Security Groups

We keep security groups pretty tight:
- ALBs only accept HTTP/HTTPS from the internet
- Instances only accept traffic from the ALB (plus SSH/RDP for management)
- Everything else is blocked by default

## Data Flow

Here's what happens when someone hits your application:

1. **User makes request** → Internet Gateway
2. **Internet Gateway** → ALB (does health check first)
3. **ALB** → Healthy EC2 instance
4. **EC2 instance** → Processes request and responds
5. **Response flows back** through the same path

The ALB is constantly checking if instances are healthy. If one goes down, traffic automatically routes to the healthy ones.

## Health Monitoring

### Built-in Health Checks

Each instance runs a simple health check script that:
- Checks if the web server is running
- Verifies disk space isn't full
- Makes sure the application is responding
- Writes status to `/health` endpoint

### What We Monitor

- **Instance health**: CPU, memory, disk usage
- **Application health**: Response times, error rates
- **Load balancer health**: Request distribution, target health

## Scaling Considerations

### Horizontal Scaling

Want more capacity? Add more instances. The ALB automatically distributes traffic across all healthy targets.

### Vertical Scaling

Need more power? Change the instance type in your tfvars file and redeploy. Terraform handles the replacement.

## File System Layout

### Linux Instances
```
/var/www/html/     # Web content
/var/log/          # Application logs
/opt/scripts/      # Custom scripts
/data/             # Additional storage
```

### Windows Instances
```
C:\inetpub\wwwroot\    # Web content
C:\Logs\               # Application logs
C:\Scripts\            # Custom scripts
D:\                    # Additional storage
```

## Security Architecture

### Defense in Depth

We implement security at multiple layers:

1. **Network**: VPC isolation, security groups, private subnets
2. **Instance**: OS-level firewalls, key-based auth, regular updates
3. **Application**: Security headers, input validation, HTTPS

### Access Control

**SSH/RDP**: Key-based authentication only. No passwords.

**Application Access**: Only through the load balancer. No direct instance access from the internet.

**Management Access**: Restricted to specific IP ranges or VPN.

## Configuration Management

### Environment Separation

Each environment has its own:
- AWS account
- Terraform state file
- Configuration variables
- Deployment pipeline

This prevents cross-environment contamination and makes it safe to experiment in dev.

### Naming Conventions

We use consistent naming:
- Resources: `{resource-type}-{environment}`
- Tags: Standardized across all resources
- Outputs: Descriptive names that make sense

## Performance Optimizations

### Load Balancing

- Round-robin distribution (default)
- Connection draining for graceful shutdowns
- Sticky sessions disabled (we assume stateless apps)

### Caching

- Static content can be cached at the ALB level
- Application-level caching is up to you
- Consider CloudFront for global distribution

## Monitoring and Observability

### What's Built In

- Health check endpoints on all instances
- Basic system monitoring (CPU, memory, disk)
- Load balancer metrics (request count, latency)
- Application logs in standard locations

### What You Can Add

- CloudWatch integration for metrics and alarms
- Custom application metrics
- Log aggregation with ELK or similar
- APM tools for application performance

## Deployment Strategy

### Infrastructure as Code

Everything is defined in Terraform. No manual clicking in the AWS console.

### State Management

- Remote state in S3 with encryption
- State locking with DynamoDB
- Separate state files per environment

### Rollback Strategy

If something goes wrong:
1. Revert to previous Terraform state
2. Redeploy known-good configuration
3. Investigate and fix the issue

## Common Patterns

### Adding New Services

1. Create or find a base module for the service
2. Add it to your `base_modules` configuration
3. Define the service spec in your tfvars
4. Deploy through the normal promotion workflow

### Scaling Up

1. Increase instance counts in tfvars
2. Deploy to dev first to test
3. Promote through staging to production
4. Monitor performance and adjust as needed

### Troubleshooting

1. Check the health endpoints first
2. Look at instance logs
3. Verify security group rules
4. Check ALB target health
5. Review Terraform state for drift

## Why We Built It This Way

**Simplicity**: We wanted something that works out of the box without a PhD in AWS.

**Flexibility**: You can adapt this for any AWS service, not just ALB/EC2.

**Safety**: The promotion workflow prevents accidents in production.

**Scalability**: This pattern works whether you have 5 instances or 500.

**Maintainability**: Everything is code, so you can version, review, and rollback changes.

This architecture isn't perfect, but it's practical. We've used it in production for months without major issues, and it's saved us countless hours of manual deployment work.
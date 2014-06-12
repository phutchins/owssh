#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'pp'
require 'command_line_reporter'

class Owssh
  include CommandLineReporter


  def get_stacks
    my_stacks = {}
    stacks_json = JSON.parse(`AWS_CONFIG_FILE=#{$aws_config_file} aws --profile #{$aws_profile} opsworks describe-stacks`)

    stacks_json['Stacks'].each do |stack|
      if $debug then puts "Stack Name: #{stack['Name'].gsub(' ','_').downcase}     Stack ID: #{stack['StackId']}" end
      stack_name = stack['Name'].gsub(' ','_').downcase
      my_stacks[stack_name.to_s] = stack['StackId']
    end
    my_stacks
  end

  def get_instances(id)
    my_instances = {}
    instances_json = JSON.parse(`AWS_CONFIG_FILE=#{$aws_config_file} aws --profile #{$aws_profile} opsworks describe-instances --stack-id #{id}`)
    instances_json['Instances'].each do |instance|
      pub_ip = instance['ElasticIp'] || instance['PublicIp'] || "N/A"
      priv_ip = instance['PrivateIp'] || "N/A"
      status = instance['Status']
      match = instance['Hostname'].match(/(.*)\d+/) rescue nil
      if !match.nil? then
        type = match[1].to_s
      else
        type = "N/A"
      end
      my_instances[instance['Hostname'].to_s] = { "PUB_IP" => pub_ip.to_s, "PRIV_IP" => priv_ip.to_s, "TYPE" => type, "STATUS" => status }
    end
    my_instances
  end

  def print_instances(instances)
    table(:border => true) do
      row do
        column('Hostname', :width => 20)
        column('Public IP', :width => 15, :align => 'right')
        column('Private IP', :width => 15, :align => 'right')
        column('Type', :width => 16)
        column('Status', :width => 8)
      end
      instances.each do |instance_name, data|
        row do
          column(instance_name)
          column(data['PUB_IP'])
          column(data['PRIV_IP'])
          column(data['TYPE'])
          column(data['STATUS'])
        end
      end
    end
  end

  def print_stacks(stacks)
    table(:border => true) do
      row do
        column('Stack Name', :width => 20)
        column('Stack ID', :width => 40, :align => 'right')
      end
      stacks.each do |stack_name, id|
        row do
          column(stack_name)
          column(id)
        end
      end
    end
  end

  def ssh_connect(connect_user, su_to_user, ssh_key, command)

  end

  def print_help
    puts "Version #{Gem.loaded_specs['owssh'].version}"
    puts ""
    puts "Usage:"
    puts "owssh list                                                   - List all environments"
    puts "owssh describe                                               - Show details of hosts in all stacks"
    puts "owssh describe [Stack Name]                                  - Show details of a specific stack"
    puts "owssh [Stack Name] [Hostname or Type]                        - SSH to a host in a stack"
    puts "owssh [Stack Name] [Hostname or Type] \"Your command here\"    - SSH to a host in a stack and run a command"
    puts ""
    puts " Type      - The type of host. I.E. rails-app, resque, etc..."
    puts " Hostname  - The name of the host. I.E. rails-app1, resque1, etc..."
    puts ""
    puts "Environment Variables:"
    puts "  AWS_DEFAULT_PROFILE         Defines the AWS config profile to use"
    puts "  OWSSH_SSH_KEY_FILE          Path to your ssh key file"
    puts "  OWSSH_AWS_CONFIG_FILE       Path to your aws config file if you want it to be different from default"
    puts "  OWSSH_USER                  The user to SSH as. Default is ubuntu"
    puts ""
    exit
  end

  def owssh
    # Export environment variables for AWS CLI here
    $debug = false
    $aws_profile = ENV['AWS_DEFAULT_PROFILE'] || "default"
    $ssh_key_file = ENV['OWSSH_SSH_KEY_FILE'] || "~/.ssh/id_rsa_owssh"
    $aws_config_file = ENV['OWSSH_AWS_CONFIG_FILE'] || ENV['AWS_CONFIG_FILE'] || "~/.aws/config.owssh"
    $ssh_user = ENV['OWSSH_USER'] || "ubuntu"

    if ARGV.empty?
      puts "Please supply some options. Try 'owssh help' for available commands"
      abort
    end

    $stacks = {}
    $instances = {}

    $stacks = get_stacks

    if ARGV[0] == "help" then
      print_help
    elsif ARGV[0] == "list" then
      # List all stacks
      puts "Getting list of stacks..."
      print_stacks($stacks)
      exit
    elsif ARGV[0] == "describe" && ARGV[1].nil? then
      # Describe all stacks
      $stacks.each do |stack_name, id|
        puts "Getting data for Stack: #{stack_name}"
        $instances = get_instances(id)
        print_instances($instances)
      end
      exit
    elsif ARGV[0] == "describe" && !ARGV[1].nil? then
      # Describe a particular stack
      stack_name = ARGV[1].downcase.to_s
      if $stacks.has_key?(stack_name) then
        if $debug then puts "Stack ID: #{$stacks[stack_name]}" end
        puts "Getting data for Stack: #{stack_name}"
        $instances = get_instances($stacks[stack_name])
        print_instances($instances)
      elsif
        puts "Unable to find stack named '#{ARGV[1]}'"
        abort
      end
    elsif $stacks.has_key?(ARGV[0].downcase.to_s) then
      # SSH to the host
      if ARGV[1].nil? then
        puts "Please enter an instance name. I.E. rails-app3"
        abort
      end

      stack_name = ARGV[0].downcase.to_s
      $instances = get_instances($stacks[stack_name])

      if $instances.has_key?(ARGV[1].downcase.to_s) then
        # SSH to specific host
        if ARGV[2].nil? then
          puts "Opening SSH connection to #{ARGV[1]}..."
          exec("ssh -i #{$ssh_key_file} #{$ssh_user}@#{$instances[ARGV[1].downcase.to_s]['PUB_IP']}")
        elsif ARGV[3].nil? then
          # Run command through SSH on host
          puts "Running comand #{ARGV[2]} on host #{ARGV[1]}..."
          exec("ssh -i #{$ssh_key_file} #{$ssh_user}@#{$instances[ARGV[1].downcase.to_s]['PUB_IP']} '#{ARGV[2]}'")
        end
      else
        # SSH to first instance of certain type
        $first_instance = ""
        $instances.each do |instance_name, data|
          unless (instance_name =~ /#{ARGV[1].to_s}(.*)/).nil? || data["STATUS"] == ( "stopped" || "pending" || "requested" || "pending" )
            $first_instance = instance_name
            break
          end
        end
        if $first_instance == "" then
          puts "Could not find valid host with name or type of '#{ARGV[1]}'"
          abort
        else
          if ARGV[2].nil? then
            puts "Opening SSH connection to first of type '#{ARGV[1]}' which is '#{$first_instance}'..."
          else
            puts "Running command '#{ARGV[2]}' on first host of type '#{ARGV[1]}' which is '#{$first_instance}'..."
          end
          exec("ssh -i #{$ssh_key_file} #{$ssh_user}@#{$instances[$first_instance.to_s]['PUB_IP']} '#{ARGV[2]}'")
        end
      end
    else
      puts "I don't quite understand what you're asking me to do..."
      puts " Try running 'owssh help' for help!"
      abort
    end
  end
end

require 'openssl'
require 'base64'
require 'json'

class PasswordManager
  # Generate a random key for encryption
  def generate_key
    OpenSSL::Cipher.new('AES-256-CBC').random_key
  end

  # Load the key from file or generate a new one
  def load_or_generate_key
    if File.exist?(@key_file)
      File.read(@key_file)
    else
      key = generate_key
      File.write(@key_file, key)
      key
    end
  end

  # Initialize the password manager with key and password file paths
  def initialize
    @key_file = "key.bin"
    @file = "passwords.json"
    @key = load_or_generate_key  # Load or generate the encryption key
    @passwords = load_passwords  # Load passwords from the file
  end

  # Load and decrypt passwords from the file
  def load_passwords
    if File.exist?(@file)
      encrypted_data = File.read(@file)
      decrypt_data(encrypted_data)
    else
      {}
    end
  end

  # Encrypt the data before storing
  def encrypt_data(data)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = @key
    iv = cipher.random_iv
    encrypted_data = cipher.update(data) + cipher.final
    Base64.encode64(iv + encrypted_data)  # Store IV + encrypted data in Base64 format
  end

  # Decrypt the stored data
  def decrypt_data(data)
    decoded_data = Base64.decode64(data)  # Decode the Base64 data
    iv = decoded_data.slice!(0, 16)  # Extract the initialization vector (IV)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.decrypt
    cipher.key = @key
    cipher.iv = iv
    cipher.update(decoded_data) + cipher.final
  rescue OpenSSL::Cipher::CipherError => e
    puts "Decryption failed: #{e.message}"
    {}
  end

  # Store a new password for a service
  def store_password(service, username, password)
    encrypted_password = encrypt_data(password)
    @passwords[service] = { username: username, password: encrypted_password }
    save_passwords
  end

  # Retrieve a password for a service
  def retrieve_password(service)
    if @passwords[service]
      decrypted_password = decrypt_data(@passwords[service][:password])
      { username: @passwords[service][:username], password: decrypted_password }
    else
      nil
    end
  end

  # Delete a stored password for a service
  def delete_password(service)
    if @passwords.delete(service)
      save_passwords
    else
      puts "Service not found."
    end
  end

  # Save the encrypted passwords to the file in the desired format
  def save_passwords
    data = { "passwords" => @passwords.transform_values { |v| v[:password] } }
    encrypted_data = encrypt_data(data.to_json)  # Encrypt the JSON data
    File.write(@file, encrypted_data)
  end

  # List all stored services
  def list_services
    puts "Stored Services:"
    @passwords.keys.each { |service| puts service }
  end
end

# Command-line interface (CLI) for the password manager
class CLI
  def initialize
    @manager = PasswordManager.new
  end

  def start
    loop do
      puts "\nPassword Manager"
      puts "1. Store Password"
      puts "2. Retrieve Password"
      puts "3. Delete Password"
      puts "4. List Services"
      puts "5. Exit"
      print "Choose an option: "
      choice = gets.chomp.to_i

      case choice
      when 1
        store_password
      when 2
        retrieve_password
      when 3
        delete_password
      when 4
        @manager.list_services
      when 5
        puts "Goodbye!"
        break
      else
        puts "Invalid option, please try again."
      end
    end
  end

  def store_password
    print "Enter service name: "
    service = gets.chomp
    print "Enter username: "
    username = gets.chomp
    print "Enter password: "
    password = gets.chomp
    @manager.store_password(service, username, password)
    puts "Password stored successfully!"
  end

  def retrieve_password
    print "Enter service name to retrieve password: "
    service = gets.chomp
    result = @manager.retrieve_password(service)
    if result
      puts "Username: #{result[:username]}"
      puts "Password: #{result[:password]}"
    else
      puts "No password found for #{service}."
    end
  end

  def delete_password
    print "Enter service name to delete: "
    service = gets.chomp
    @manager.delete_password(service)
    puts "#{service} password deleted."
  end
end

# Start the command-line interface (CLI)
CLI.new.start

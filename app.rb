# Fonctionalité
## Suivre le taux de remplissage par séance.
# 1. Se connecter sur l'application avec le login et mot de passe
# 2. uploader le fichier csv contenant la liste des tickets provenant de weezevent
# 3. le taux de remplissage s'affiche pour chaque Séance du festival
# 
# TODO: utiliser directement l'API de weezevent...
#   http://www.weezevent.com/developpement_api.php

require 'sinatra'
require 'dotenv'
require 'csv'
require 'haml'
require 'pry' if ENV['RACK_ENV'] == "development"

###############################################################################
### ROUTES
Dotenv.load
use Rack::Auth::Basic, "Multipass !" do |username, password|
  username == ENV['LOGIN'] and password == ENV['SECRET_PASSWORD']
end

@@file = nil

get '/' do
  haml :upload
end

post '/' do
  unless params[:file] &&
    (tmpfile = params[:file][:tempfile]) &&
    (name = params[:file][:filename])
    @error = "No file selected"
    return haml(:upload)
  end
  @@file = params[:file][:tempfile]
  redirect to ('/index')
end

get '/index' do
  redirect to ('/') unless @@file

  import = ImportController.new(@@file)
  @tickets = import.tickets
  @projections = import.projections
  haml :index
end

###############################################################################
### MODELS and CONTROLLERS

class ImportController

  def initialize(file)
    @rows = set_rows(file)
    @tickets = set_tickets
    @projections = set_projections
  end

  def tickets
    @tickets
  end

  def projections
    @projections
  end

  private

  def set_rows(file)
    content = File.read(file).sub(/^\xEF\xBB\xBF/, '')
    CSV.parse(content, headers: true, col_sep: ';')
  end

  def set_tickets
    @rows.map { |row| Ticket.new(row) }
  end

  def set_projections
    @tickets.map do |ticket|
      Projection.new(
        id: ticket.projection_id,
        film: ticket.film,
        capacity: ticket.room_capacity,
        booked_seats: booked_seats(ticket.projection_id))
    end
      .uniq{ |projection| projection.id }
      .sort{ |px, py| px.id <=> py.id }
  end

  def booked_seats(projection_id)
    @tickets.count{ |ticket| ticket.projection_id == projection_id }
  end

end

class Projection
  attr_accessor :id, :capacity, :film, :booked_seats
  def initialize(params)
    @id = params[:id]
    @film = params[:film]
    @capacity = params[:capacity]
    @booked_seats = params[:booked_seats]
  end

  def booking_rate
    (100 * @booked_seats.to_f / @capacity).round
  end
end

class Ticket

  SEATS = [200, 180, 70]

  def initialize(row)
    @description = row['Catégorie']
  end

  def film
    @description.match(/\| Salle.* \- .* \- (.*) \-/)[1]
  end

  def projection_id
    @description.match(/\(séance (\d+)\)/)[1].to_i
  end
   
  def room_capacity
    SEATS[room_id - 1]
  end

  private

  def room_id
    @description.match(/\| Salle (\d) \-/)[1].to_i
  end
 
end

__END__

###############################################################################
### VIEWS

@@ layout
!!!
%html
  %head
    %title Suivi réservations festival 2015
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
    :css
      input.btn, a.btn {
        margin-top: 15px;
      }
  %body
    .container
      = yield
      <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/js/bootstrap.min.js"></script>

@@ upload
.col-md-8.col-md-offset-2
  %h1 Charger un fichier
  %p
    La liste des tickets au format .csv téléchargée depuis
    %a{href: "https://www.weezevent.com/login", target: "_blank"} la billeterie.
  %form.form-inline{action: "/", method: :post, enctype: "multipart/form-data"}
    %input{type: :file, name: :file, accept: ".csv"}
    %input.btn.btn-primary{type: :submit, value: "Envoyer"}

@@ index
%a.btn.btn-default{href: '/'} Charger un nouveau fichier
%h1 Suivi du remplissage des salles par séance - festival 2015
- @projections.each do |projection|
  .row
    .col-md-2
      %p.pull-right
        Séance 
        = projection.id
    .col-md-4
      .progress
        .progress-bar(role="progressbar" style="min-width: 2em; width: #{projection.booking_rate}%")
          = "#{projection.booking_rate}%"
    %p
      = projection.capacity - projection.booked_seats
      sièges libres
      \-
      = projection.film
%h3
  TOTAL:
  = @tickets.count
  billets


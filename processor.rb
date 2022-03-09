require "csv"
require "pry"
require "json"

class Processor
  def initialize
    @professions = CSV.open("./data/professions.csv", encoding: "bom|utf-8", headers: true).to_a
    @organisations = CSV.open("./data/organisations.csv", encoding: "bom|utf-8", headers: true).to_a
    @legislation = CSV.open("./data/legislation.csv", encoding: "bom|utf-8", headers: true).to_a

    @legislation_to_professions = CSV.open("./data/legislation-to-professions.csv", encoding: "bom|utf-8", headers: true).to_a
    @professions_to_orgs = CSV.open("./data/professions-to-orgs.csv", encoding: "bom|utf-8", headers: true).to_a
    @soc_codes = CSV.open("./data/soccodes.csv", encoding: "bom|utf-8", headers: true).to_a
  end

  def parsed_organisations
    @organisations.map { |organisation|
      {
        name: organisation["Organisation Name"],
        slug: slugify(organisation["Organisation Name"]),
        versions: [
          {
            alternateName: organisation["Alternate Name"],
            address: [organisation["Address"], organisation["City"], organisation["Postcode"]].join(","),
            url: organisation["Website"],
            email: organisation["Email"],
            contactUrl: "",
            telephone: organisation["Phone Number"],
            fax: "",
            status: "live"
          }
        ]
      }
    }
  end

  def parsed_professions
    professions = []

    @professions.each do |profession|
      profession = {
        name: profession["Name"],
        organisation: fetch_organisations(profession["ProfID"])[0],
        additionalOrganisation: fetch_organisations(profession["ProfID"])[1],
        versions: [
          {
            alternateName: profession["Other Title(s)"],
            description: profession["Description"],
            occupationLocations: parse_locations(profession["Jurisdiction"]),
            regulationType: convert_regulation_type(profession["Regulation Type"]),
            industries: [fetch_industry(profession["BEIS defined sector"])],
            qualification: "DSE - Diploma (post-secondary education), including Annex II (ex 92/51, Annex C,D) , Art. 11 c",
            protectedTitles: profession["Other Protected Title(s)"],
            regulationUrl: "",
            reservedActivities: profession["Reserved Activities"],
            legislations: fetch_legislation(profession["ProfID"]),
            mandatoryRegistration: "voluntary",
            status: "draft",
            socCode: profession["SOC"].to_i,
            keywords: keywords_from_soccode(profession["SOC"])
          }
        ]
      }

      tries = 0
      loop do
        slug = slugify(profession[:name])

        profession[:slug] = if tries == 0
          slug
        else
          "#{slug}-#{tries}"
        end

        break if professions.find { |p| p[:slug] == profession[:slug] }.nil?

        tries += 1
      end

      professions << profession
    end

    professions
  end

  def parsed_qualifications
    [{
      level: "DSE - Diploma (post-secondary education), including Annex II (ex 92/51, Annex C,D) , Art. 11 c",
      methodToObtain: "generalSecondaryEducation",
      otherMethodToObtain: "",
      commonPathToObtain: "generalSecondaryEducation",
      otherCommonPathToObtain: "",
      educationDuration: " 5.0 Year",
      educationDurationYears: 5,
      educationDurationMonths: 0,
      educationDurationDays: 0,
      educationDurationHours: 0,
      mandatoryProfessionalExperience: true
    }]
  end

  def parsed_legislation
    @legislation.map { |legislation|
      {
        name: legislation["Legislation Name"],
        url: legislation["Legislation Link"]
      }
    }
  end

  private

  def fetch_organisations(id)
    mappings = @professions_to_orgs.select { |profession| profession["ProfID"].strip == id.strip }

    organisations = mappings.map { |mapping|
      @organisations.find { |o|
        mapping["OrgID"] == o["OrgID"]
      }
    }

    organisations.map { |o| o["Organisation Name"] }
  end

  def slugify(string)
    string.downcase.strip.tr(" ", "-").gsub(/[^\w-]/, "")
  end

  def parse_locations(locations)
    locations.split(", ").map { |location|
      case location
      when "UK"
        ["GB-ENG", "GB-SCT", "GB-WLS", "GB-NIR"]
      when "Wales"
        "GB-WLS"
      when "Scotland"
        "GB-SCT"
      when "Northern Ireland"
        "GB-NIR"
      when "England"
        "GB-ENG"
      end
    }.flatten
  end

  def fetch_industry(industry)
    {
      "Education" => "industries.education",
      "Health" => "industries.health",
      "Legal" => "industries.law",
      "Architecture" => "industries.architecture",
      "Finance and Insurance" => "industries.finance",
      "Social Services" => "industries.socialServices",
      "Transport" => "industries.transport",
      "Other" => "industries.other",
      "Construction and Engineering" => "industries.constructionAndEngineering",
      "Science" => "industries.science",
      "Surveying" => "industries.surveying"
    }[industry.strip]
  end

  def fetch_legislation(id)
    ids = @legislation_to_professions.select { |legislation| legislation["ProfID"] == id }.map { |l| l["LegID"] }.compact
    @legislation.select { |legislation| ids.include?(legislation["LegislationID"]) }.map { |l| l["Legislation Name"] }
  end

  def keywords_from_soccode(code)
    @soc_codes.select { |r| r["SOCID"] == code }.map { |r| r["IndexTerm"] }.join(",")
  end

  def convert_regulation_type(field)
    return nil if field.to_s.strip.empty?

    field.split(" - ")[0].downcase
  end
end

processor = Processor.new

File.write("out/professions.json", JSON.pretty_generate(processor.parsed_professions))
File.write("out/organisations.json", JSON.pretty_generate(processor.parsed_organisations))
File.write("out/legislations.json", JSON.pretty_generate(processor.parsed_legislation))
File.write("out/qualifications.json", JSON.pretty_generate(processor.parsed_qualifications))

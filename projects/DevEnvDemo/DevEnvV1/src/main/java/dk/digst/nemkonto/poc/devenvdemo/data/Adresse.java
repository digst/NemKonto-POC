package dk.digst.nemkonto.poc.devenvdemo.data;

import javax.annotation.Generated;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * En adresse, tilhørende en konto
 * @author Thomas Thorndahl (thomas@codecast.dk)
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("org.jsonschema2pojo")
public final class Adresse {
	
	private String land;
	private String adresse;
	private String postnr;
	private String postdistrikt;
	private String konteringsadressetype;
	
	public Adresse() { }
	
	public Adresse(String land, String adresse, String postnr, String postdistrikt, String konteringsadressetype) {
		this.land = land;
		this.adresse = adresse;
		this.postnr = postnr;
		this.postdistrikt = postdistrikt;
		this.konteringsadressetype = konteringsadressetype;
	}
	
	@JsonProperty("land")
	public String getLand() {
		return land;
	}
	public void setLand(String land) {
		this.land = land;
	}
	@JsonProperty("adresse")
	public String getAdresse() {
		return adresse;
	}
	public void setAdresse(String adresse) {
		this.adresse = adresse;
	}
	@JsonProperty("postnr")
	public String getPostnr() {
		return postnr;
	}
	public void setPostnr(String postnr) {
		this.postnr = postnr;
	}
	@JsonProperty("postdistrikt")
	public String getPostdistrikt() {
		return postdistrikt;
	}
	public void setPostdistrikt(String postdistrikt) {
		this.postdistrikt = postdistrikt;
	}
	@JsonProperty("konteringsadressetype")
	public String getKonteringsadressetype() {
		return konteringsadressetype;
	}
	public void setKonteringsadressetype(String konteringsadressetype) {
		this.konteringsadressetype = konteringsadressetype;
	}
}

﻿drop view if exists DATAWG.biomass_synthesis CASCADE;
create or REPLACE view DATAWG.biomass_synthesis AS
with B0_avg AS
	(with B0_AL AS
		(select EEL_COU_CODE, EEL_EMU_NAMESHORT, EEL_YEAR, 
		case when count(eel_value)< COUNT(*) then null else SUM(eel_value) end -- by default sum of null and value is not a null value, this part correct that
		from DATAWG.B0
		group by EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR)
		-- pour gerer la merde
	select EEL_COU_CODE,EEL_EMU_NAMESHORT, AVG(SUM) as b0_avg from B0_AL
	group by EEL_COU_CODE,EEL_EMU_NAMESHORT),
	B0_AL AS
		(select EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR,
		case when count(eel_value)< COUNT(*) then null else SUM(eel_value) end as b0-- by default sum of null and value is not a null value, this part correct that
		from DATAWG.B0
		group by EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR),
	Bbest_AL AS
		(select EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR, 
		case when count(eel_value)< COUNT(*) then null else SUM(eel_value) end as bbest -- by default sum of null and value is not a null value, this part correct that
		from DATAWG.Bbest
		group by EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR), 
	Bcurrent_AL as
	(select EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR,
	case when count(eel_value)< COUNT(*) then null else SUM(eel_value) end as bcurrent -- by default sum of null and value is not a null value, this part correct that 
	from DATAWG.BCURRENT
group by EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR)
select EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, COALESCE(b0, b0_avg) as b0, bbest, bcurrent from bcurrent_AL 
join B0_avg using(EEL_COU_CODE,EEL_EMU_NAMESHORT) 
left outer join Bbest_AL using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year)
left OUTER join B0_AL using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year)
;

SELECT * from DATAWG.BIOMASS_SYNTHESIS order by eel_emu_nameshort, eel_year;

-- aggregation at the country level
SELECT EEL_COU_CODE, eel_year, 
case when count(B0)< COUNT(*) then null else SUM(B0) end as B0,
case when count(Bbest)< COUNT(*) then null else SUM(Bbest) end as Bbest,
case when count(Bcurrent)< COUNT(*) then null else SUM(Bcurrent) end as Bcurrent
from DATAWG.BIOMASS_SYNTHESIS
group by EEL_COU_CODE, eel_year;

drop view if exists DATAWG.mortality_synthesis CASCADE ;
create or REPLACE view DATAWG.mortality_synthesis AS
with sigma AS
	(select EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code, eel_value as suma from DATAWG.SIGMAA),
	sigmaf AS
	(select EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code, eel_value as sumf from DATAWG.SIGMAf),
	sigmah AS
	(select EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code, eel_value as sumh from DATAWG.SIGMAh),
	Bbest AS
	(select EEL_COU_CODE,EEL_EMU_NAMESHORT, EEL_YEAR, eel_hty_code, eel_value as bbest from DATAWG.Bbest)
select *, suma*bbest as sab, sumf*bbest as sfb, sumh*bbest as shb from sigma
left outer join sigmaf using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code)
left outer join sigmah using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code)
left outer join bbest using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year, eel_hty_code)
;

select * from DATAWG.MORTALITY_SYNTHESIS;



-- precodata at the emu level
drop view if exists DATAWG.precodata_emu CASCADE;
create or REPLACE view DATAWG.precodata_emu as
select EEL_COU_CODE, EEL_EMU_NAMESHORT, EEL_EMU_NAMESHORT as aggreg_area, eel_year, b0, BIOMASS_SYNTHESIS.bbest, bcurrent, 
round(case when EEL_COU_CODE = 'IE' THEN sum(suma) -- solved case when suma in AL only (IE)
	when BIOMASS_SYNTHESIS.bbest > 0 then sum(sab)/(BIOMASS_SYNTHESIS.bbest) ELSE NULL end, 2) as suma,
round(case when EEL_COU_CODE = 'IE' THEN sum(sumf) -- solved case when suma in AL only (I
	when BIOMASS_SYNTHESIS.bbest > 0 then sum(sfb)/(BIOMASS_SYNTHESIS.bbest) ELSE NULL end, 2) as sumf,
round(case when EEL_COU_CODE = 'IE' THEN sum(sumh) -- solved case when suma in AL only (I
	when BIOMASS_SYNTHESIS.bbest > 0 then sum(shb)/(BIOMASS_SYNTHESIS.bbest) ELSE NULL end, 2) as sumh,
'emu'::text as aggreg_level
from DATAWG.MORTALITY_SYNTHESIS left outer join DATAWG.BIOMASS_SYNTHESIS using(EEL_COU_CODE,EEL_EMU_NAMESHORT, eel_year)
group by EEL_COU_CODE, EEL_EMU_NAMESHORT, eel_year, b0, BIOMASS_SYNTHESIS.bbest, bcurrent
;

select * from DATAWG.PRECODATA_EMU;

-- precodata at the country level
drop view if exists DATAWG.precodata_country  cascade;
create or REPLACE view DATAWG.precodata_country as
with country_biomass as
	(SELECT EEL_COU_CODE, eel_year, 
	case when count(B0)< COUNT(*) then null else SUM(B0) end as B0, -- by default sum of null and value is not a null value, this part correct that
	case when count(BBest)< COUNT(*) then null else SUM(BBest) end as BBest, -- by default sum of null and value is not a null value, this part correct that
	case when count(Bcurrent)< COUNT(*) then null else SUM(Bcurrent) end as Bcurrent-- by default sum of null and value is not a null value, this part correct that
	from DATAWG.PRECODATA_EMU 
	group by EEL_COU_CODE, eel_year)
select EEL_COU_CODE, null::character varying(20) EEL_EMU_NAMESHORT, EEL_COU_CODE as aggreg_area, eel_year, round(country_biomass.b0/1000) as b0, round(country_biomass.bbest/1000) as bbest, round(country_biomass.bcurrent/1000) as bcurrent, 
round(case when country_biomass.bbest > 0 then sum(suma * PRECODATA_EMU.bbest)/(country_biomass.bbest) ELSE NULL end, 2) as suma,
round(case when country_biomass.bbest > 0 then sum(sumf * PRECODATA_EMU.bbest)/(country_biomass.bbest) ELSE NULL end, 2) as sumf,
round(case when country_biomass.bbest > 0 then sum(sumh * PRECODATA_EMU.bbest)/(country_biomass.bbest) ELSE NULL end, 2) as sumh,
'country'::text as aggreg_level
from DATAWG.PRECODATA_EMU left outer join country_biomass using(EEL_COU_CODE, eel_year)
group by EEL_COU_CODE, eel_year, country_biomass.b0, country_biomass.bbest, country_biomass.bcurrent
;

SELECT * from DATAWG.PRECODATA_COUNTRY ;

-- precodata for all country
drop view if exists DATAWG.precodata_all;
create or REPLACE view DATAWG.precodata_all as
with all_level as
(
	(with last_year_emu as
		(select EEL_EMU_NAMESHORT, max(EEL_YEAR) as last_year from DATAWG.PRECODATA_emu 
		where b0 is not null and bbest is not null and bcurrent is not null and suma is not null group by EEL_EMU_NAMESHORT) --last year should the last COMPLETE (b0, bbest, bcurrent, suma) year
	select eel_cou_code, eel_emu_nameshort, aggreg_area, eel_year, b0, bbest, bcurrent, suma, sumf, sumh, aggreg_level, last_year from DATAWG.precodata_emu join last_year_emu using(EEL_EMU_NAMESHORT))
	union
	(with last_year_country as
		(select EEL_COU_CODE, max(EEL_YEAR) as last_year from DATAWG.PRECODATA_COUNTRY
		where b0 is not null and bbest is not null and bcurrent is not null and suma is not null group by EEL_COU_CODE) --last year should the last COMPLETE (b0, bbest, bcurrent, suma) year
	select * from DATAWG.precodata_country join last_year_country using(EEL_COU_CODE))
	union
	(select null EEL_COU_CODE, null::character varying(20) EEL_EMU_NAMESHORT, 'All (' || count(*) || ' countries: ' || string_agg(EEL_COU_CODE, ',') || ')' AGGREG_AREA, eel_year, 
		sum(b0) as b0, sum(bbest)as bbest, sum(bcurrent)as bcurrent,
		round(sum(suma*bbest)/sum(bbest),2) as suma, 
		case when count(sumf)< COUNT(*) then null else round(sum(sumf*bbest)/sum(bbest),2) end as sumf, -- by default sum of null and value is not a null value, this part correct that
		case when count(sumh)< COUNT(*) then null else round(sum(sumh*bbest)/sum(bbest),2) end as sumf, -- by default sum of null and value is not a null value, this part correct that
		'all' as aggreg_level, null last_year
	from DATAWG.precodata_country
	where b0 is not null and bbest is not null and BCURRENT is not NULL and SUMA is not null
	group by EEL_YEAR)
) select all_level.* from all_level left outer join "ref".TR_COUNTRY_COU on EEL_COU_CODE = cou_code
order by eel_year,
-- order my aggreg_level: emu, country, all
case 
	when aggreg_level = 'emu' then 1
	when aggreg_level = 'country' then 2
	when aggreg_level = 'all' then 3
end,
cou_order, EEL_EMU_NAMESHORT 
;

select * from DATAWG.precodata_all;
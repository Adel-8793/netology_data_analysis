--Итоговая работа

  --1.Название самолетов,которые имеют менее 50 посадочных мест 
select model
from aircrafts a
join (select aircraft_code,
             count(seat_no) 
      from seats 
      group by aircraft_code) as t on a.aircraft_code =t.aircraft_code 
group by model, t.count 
having t.count <'50';

--2.Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
select t.sum, 
      t.date_trunc as number_month,
      round(((t.sum - lag(t.sum, 1) over (order by t.date_trunc asc))/ 
		lag(t.sum, 1) over (order by t.date_trunc asc))*100,2) as percentage_change
from (select date_trunc('month', b.book_date) , sum(b.total_amount)   
	  from bookings b
	  group by 1
	 order by 1) t;
	 

--3.Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.
 
select a.model
from  aircrafts a 
join( select s.aircraft_code
from seats s
group by 1
having 'Business' <>  all  (array_agg(s.fare_conditions))) t on t.aircraft_code =a.aircraft_code;


-- 4.Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день.
-- Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
--Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.

with c as (
	select departure_airport, actual_departure, actual_departure::date ad_date, c_s
	from flights f
	join (
		select aircraft_code, count(*) c_s
		from seats
		group by aircraft_code) s on s.aircraft_code = f.aircraft_code
	left join boarding_passes bp on bp.flight_id = f.flight_id
	where actual_departure is not null and bp.flight_id is null)
select departure_airport, ad_date, c_s, sum(c_s) over (partition by departure_airport, ad_date order by actual_departure)
from c 
where (departure_airport, ad_date) in (
	select departure_airport, ad_date
	from c 
	group by 1,2 
	having count(*) > 1)
	
-- 5.Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов.
-- Выведите в результат названия аэропортов и процентное отношение.
--Используйте в решении оконную функцию.

select d.airport_name, a.airport_name, round(count(*) * 100. / sum(count(*)) over () , 3)
from flights f
join airports d on f.departure_airport = d.airport_code
join airports a on f.arrival_airport = a.airport_code
group by 1, 2 

--6.Выведите количество пассажиров по каждому коду сотового оператора.
-- Код оператора – это три символа после +7
 
select substring(t.number from 4 for 3) as operator_code,
       count(t.passenger_id) as count_pas
from (select (contact_data -> 'phone')::text as number,
              passenger_id
      from tickets) t
group by substring(t.number from 4 for 3);

--7.Классифицируйте финансовые обороты (сумму стоимости билетов) по маршрутам:
--до 50 млн – low
--от 50 млн включительно до 150 млн – middle
--от 150 млн включительно – high
--Выведите в результат количество маршрутов в каждом полученном классе.

select *
from (select t.grade,
            count(t.flight_no) over (partition by t.grade)
	  from (select flight_no,
	               sum(tf.amount),
					case when sum(tf.amount) < 50000000 then 'low'
						 when sum(tf.amount) >= 50000000 and sum(tf.amount) < 150000000 then 'middle'
						 else 'high'
					end as grade
			from flights f 
			join ticket_flights tf on tf.flight_id = f.flight_id 
			group by flight_no ) t) t1
group by t1.grade, t1.count;


--8.Вычислите медиану стоимости билетов, медиану стоимости бронирования
-- и отношение медианы бронирования к медиане стоимости билетов, результат округлите до сотых. 

select t2.mediana_bookings, t1.mediana_tickets, round(t2.mediana_bookings /  t1.mediana_tickets, 2)
from (select percentile_cont(0.5) within group(order by amount)::numeric mediana_tickets from ticket_flights) t1,
	(select percentile_cont(0.5) within group(order by total_amount)::numeric mediana_bookings from bookings) t2

--9.Найдите значение минимальной стоимости одного километра полёта для пассажира.
-- Для этого определите расстояние между аэропортами и учтите стоимость билетов.
--Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. 
--Для работы данного модуля нужно установить ещё один модуль – cube.

	
	
	
create extension cube
 create extension earthdistance
 
select t.departure_airport,
       t.arrival_airport,
       min(t.min_price/t. distance) as min_price_on_1_km
from
   (select st.departure_airport,
           st.arrival_airport,
           st.start_lng,
           st.start_lat,
           st.min_price,
           a.longitude as end_lng,
           a.latitude as end_lat,
     (earth_distance (ll_to_earth (st.start_lat,st.start_lng ), ll_to_earth (a.latitude , a.longitude))::int)/1000 as distance
     from(
        select  f.departure_airport,
               f.arrival_airport,
              a.longitude as start_lng,
              a.latitude as start_lat,
              min(tf.amount) as min_price
        from flights f 
        left join airports a on a.airport_code = f.departure_airport
        left join ticket_flights tf on tf.flight_id = f.flight_id
	    group by 1,2,a.airport_code) st
   left join airports a on a.airport_code = st.arrival_airport) t
group by 1,2
order by 3
limit 1;


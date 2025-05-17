create or replace function uuidv7() returns uuid
as $$
  select encode(
    set_bit(
      set_bit(
        overlay(uuid_send(gen_random_uuid()) placing
          substring(int8send((extract(epoch from clock_timestamp())*1000)::bigint) from 3)
          from 1 for 6),
      52, 1),
    53, 1), 'hex')::uuid;
$$ language sql volatile;

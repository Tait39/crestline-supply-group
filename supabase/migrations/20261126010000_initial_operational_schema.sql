-- Crestline Supply Group: initial operational database schema
-- PostgreSQL / Supabase. This migration creates structure only; it does not invent
-- products, suppliers, customers, stock, prices, registrations, or trading history.
-- Apply only after connecting the intended Supabase project.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'staff' check (role in ('owner','admin','procurement','sales','finance','staff')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_settings (
  id uuid primary key default gen_random_uuid(),
  legal_name text,
  trading_name text not null default 'Crestline Supply Group',
  registration_number text,
  tax_number text,
  country text not null default 'Zimbabwe',
  base_currency text not null default 'USD',
  public_email text,
  public_phone text,
  whatsapp_number text,
  physical_address text,
  postal_address text,
  website_url text,
  compliance_status text not null default 'unverified' check (compliance_status in ('unverified','in_progress','verified')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.product_categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.product_categories(id) on delete set null,
  sku text unique,
  name text not null,
  slug text not null unique,
  description text,
  brand text,
  unit_of_measure text not null default 'unit',
  currency text,
  indicative_unit_price numeric(14,2) check (indicative_unit_price is null or indicative_unit_price >= 0),
  image_url text,
  is_published boolean not null default false,
  availability_status text not null default 'quote_required' check (availability_status in ('quote_required','in_stock','limited','out_of_stock','discontinued')),
  source_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  supplier_code text unique,
  legal_name text not null,
  trading_name text,
  contact_person text,
  email text,
  phone text,
  whatsapp_number text,
  website_url text,
  country text not null default 'Zimbabwe',
  city text,
  physical_address text,
  tax_number text,
  registration_number text,
  payment_terms text,
  delivery_terms text,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','rejected')),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supplier_products (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  supplier_sku text,
  last_quoted_price numeric(14,2) check (last_quoted_price is null or last_quoted_price >= 0),
  currency text,
  minimum_order_quantity numeric(14,3),
  lead_time_days integer,
  last_verified_at timestamptz,
  notes text,
  unique (supplier_id, product_id)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_code text unique,
  organisation_name text not null,
  organisation_type text,
  contact_person text,
  email text,
  phone text,
  whatsapp_number text,
  country text not null default 'Zimbabwe',
  city text,
  physical_address text,
  billing_address text,
  tax_number text,
  payment_terms text,
  customer_status text not null default 'prospect' check (customer_status in ('prospect','active','on_hold','inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  quote_number text not null unique,
  customer_id uuid references public.customers(id) on delete set null,
  requested_by_name text,
  requested_by_email text,
  requested_by_phone text,
  organisation_name text,
  status text not null default 'draft' check (status in ('draft','submitted','reviewing','awaiting_supplier_pricing','sent','accepted','declined','expired','cancelled')),
  currency text not null default 'USD',
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  required_by date,
  delivery_location text,
  notes text,
  internal_notes text,
  created_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz,
  valid_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  item_description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_of_measure text not null default 'unit',
  unit_price numeric(14,2) check (unit_price is null or unit_price >= 0),
  line_total numeric(14,2) check (line_total is null or line_total >= 0),
  supplier_id uuid references public.suppliers(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text not null unique,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  quote_id uuid references public.quotes(id) on delete set null,
  status text not null default 'draft' check (status in ('draft','sent','acknowledged','partially_received','received','cancelled')),
  currency text not null default 'USD',
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  ordered_at date,
  expected_delivery_date date,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  item_description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_of_measure text not null default 'unit',
  unit_cost numeric(14,2) check (unit_cost is null or unit_cost >= 0),
  line_total numeric(14,2) check (line_total is null or line_total >= 0),
  quantity_received numeric(14,3) not null default 0 check (quantity_received >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.tenders (
  id uuid primary key default gen_random_uuid(),
  tender_reference text,
  title text not null,
  procuring_entity text not null,
  source_url text,
  category text,
  country text not null default 'Zimbabwe',
  published_date date,
  closing_date timestamptz,
  estimated_value numeric(14,2),
  currency text,
  eligibility_notes text,
  required_documents text[],
  status text not null default 'researching' check (status in ('researching','qualified','not_qualified','preparing','submitted','won','lost','cancelled','closed')),
  bid_amount numeric(14,2),
  outcome_notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_documents (
  id uuid primary key default gen_random_uuid(),
  document_name text not null,
  document_type text not null,
  storage_path text,
  issuing_authority text,
  issue_date date,
  expiry_date date,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','expired')),
  notes text,
  uploaded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  entity_type text not null,
  entity_id uuid,
  action text not null,
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists products_category_idx on public.products(category_id);
create index if not exists products_published_idx on public.products(is_published, availability_status);
create index if not exists suppliers_verification_idx on public.suppliers(verification_status);
create index if not exists customers_status_idx on public.customers(customer_status);
create index if not exists quotes_status_created_idx on public.quotes(status, created_at desc);
create index if not exists quote_items_quote_idx on public.quote_items(quote_id);
create index if not exists purchase_orders_supplier_idx on public.purchase_orders(supplier_id);
create index if not exists tenders_closing_idx on public.tenders(closing_date);
create index if not exists tenders_status_idx on public.tenders(status);
create index if not exists documents_expiry_idx on public.business_documents(expiry_date);

do $$
declare t text;
begin
  foreach t in array array['profiles','business_settings','product_categories','products','suppliers','customers','quotes','purchase_orders','tenders','business_documents'] loop
    execute format('drop trigger if exists %I_updated_at on public.%I', t, t);
    execute format('create trigger %I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- Enable RLS everywhere. No anonymous access to internal records.
alter table public.profiles enable row level security;
alter table public.business_settings enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.suppliers enable row level security;
alter table public.supplier_products enable row level security;
alter table public.customers enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
alter table public.tenders enable row level security;
alter table public.business_documents enable row level security;
alter table public.activity_log enable row level security;

-- Authenticated staff can read operational records. Writes are restricted to
-- authenticated users with an active profile; role-specific permissions will be
-- tightened when the admin portal and approval workflows are implemented.
create policy "staff read profiles" on public.profiles for select to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active));
create policy "staff read business settings" on public.business_settings for select to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active));
create policy "staff manage business settings" on public.business_settings for all to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active and p.role in ('owner','admin')))
with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active and p.role in ('owner','admin')));

-- Reusable staff-access policies for internal tables.
do $$
declare t text;
begin
  foreach t in array array['product_categories','products','suppliers','supplier_products','customers','quotes','quote_items','purchase_orders','purchase_order_items','tenders','business_documents','activity_log'] loop
    execute format('create policy %I on public.%I for select to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active))', 'staff_read_' || t, t);
    execute format('create policy %I on public.%I for insert to authenticated with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active))', 'staff_insert_' || t, t);
    execute format('create policy %I on public.%I for update to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active)) with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active))', 'staff_update_' || t, t);
    execute format('create policy %I on public.%I for delete to authenticated using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active and p.role in (''owner'',''admin'')))', 'admin_delete_' || t, t);
  end loop;
end $$;

-- Public quote requests must be submitted through a validated server-side
-- endpoint/RPC. Do not expose direct anonymous INSERT policies on quotes/items.
